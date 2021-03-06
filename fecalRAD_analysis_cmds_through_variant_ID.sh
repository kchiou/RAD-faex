#!/bin/bash

# ----------------------------------------------------------------------------------------
# --- Copy in data, prepare to start mapping, etc.
# ----------------------------------------------------------------------------------------

mkdir -p /scratch/cmb433/fecalRAD
cd /scratch/cmb433/fecalRAD/

module load git/intel/1.9.4 
git clone https://github.com/bergeycm/NGS-map.git

# Copy in baboon genome
cp -r /archive/cmb433/papAnu2 NGS-map/genomes/

# ----------------------------------------------------------------------------------------

mkdir data
cd data

# First MiSeq run
aws s3 cp s3://fecalrad-test-miseq-dec2014/analysis_17009997_fastq.zip .
aws s3 cp s3://fecalrad-test-miseq-dec2014/analysis_17009997_fastq.zip.md5 .

# Second MiSeq run
aws s3 cp s3://fecalrad-test-miseq-feb2015/lane1_NoIndex_L001_R1_001.fastq.gz .
aws s3 cp s3://fecalrad-test-miseq-feb2015/lane1_NoIndex_L001_R2_001.fastq.gz .

# Third MiSeq run (done twice since yield was so low)
# First attempt
aws s3 cp s3://fecalrad-test-miseq-sept2015-take1/lane2_NoIndex_L001_R1_001.fastq.gz .
aws s3 cp s3://fecalrad-test-miseq-sept2015-take1/lane2_NoIndex_L001_R2_001.fastq.gz .
# Second attempt
aws s3 cp s3://fecalrad-test-miseq-sept2015-take2/FecSeq_S1_L001_R1_001.fastq.gz .
aws s3 cp s3://fecalrad-test-miseq-sept2015-take2/FecSeq_S1_L001_R2_001.fastq.gz .

# Confirm transfer integrity
md5sum analysis_17009997_fastq.zip > hpc.md5
cat *.md5

unzip aws s3 cp s3://fecalrad-test-miseq-dec2014/analysis_17009997_fastq.zip
mv Data/Intensities/BaseCalls/*.fastq.gz .
rm -r Data/

# Bring in barcodes and demultiplexing scripts
aws s3 cp s3://fecalrad-test-miseq-dec2014/ddRADseq_adapter_P1-flex_barcodes_sabre.txt .
aws s3 cp s3://fecalrad-test-miseq-sept2015-take1/ddRADseq_adapter_P1-flex_barcodes_sabre_12barcodes.txt .

aws s3 cp s3://fecalrad-test-miseq-dec2014/demultiplex_fecalRAD_run1.pl .
aws s3 cp s3://fecalrad-test-miseq-feb2015/demultiplex_fecalRAD_run2.pl .
aws s3 cp s3://fecalrad-test-miseq-sept2015-take1/demultiplex_fecalRAD_run3.pl .

mkdir demultiplexed

# ----------------------------------------------------------------------------------------

# Demultiplex and rename/move
perl demultiplex_fecalRAD_run1.pl
perl demultiplex_fecalRAD_run2.pl
perl demultiplex_fecalRAD_run3.pl

for i in {1..4}
do
	for j in {1..8}
	do
		mv demultiplexed/BC${i}-BC${j}_R1.fastq \
			../NGS-map/data/fecalRAD-BC${i}-BC${j}.R1.fastq
		mv demultiplexed/BC${i}-BC${j}_R2.fastq \
			../NGS-map/data/fecalRAD-BC${i}-BC${j}.R2.fastq
	done
done

# Rename 2nd run's read to BC9-*
for j in {1..12}
do
	mv demultiplexed/run2-BC${j}_R1.fastq ../NGS-map/data/fecalRAD-BC9-BC${j}.R1.fastq
	mv demultiplexed/run2-BC${j}_R2.fastq ../NGS-map/data/fecalRAD-BC9-BC${j}.R2.fastq
done

# Rename 3rd run's read to BC10-*
for j in {1..12}
do
	mv demultiplexed/run3-BC${j}_R1.fastq ../NGS-map/data/fecalRAD-BC10-BC${j}.R1.fastq
	mv demultiplexed/run3-BC${j}_R2.fastq ../NGS-map/data/fecalRAD-BC10-BC${j}.R2.fastq
done

# ----------------------------------------------------------------------------------------

# Clean up.

rm *.fastq
rm demultiplexed/*

# ----------------------------------------------------------------------------------------

# Remove unused barcodes
cd ../NGS-map/

rm data/fecalRAD-BC1-BC4.R*.fastq
rm data/fecalRAD-BC1-BC5.R*.fastq
rm data/fecalRAD-BC1-BC6.R*.fastq
rm data/fecalRAD-BC1-BC7.R*.fastq
rm data/fecalRAD-BC1-BC8.R*.fastq
rm data/fecalRAD-BC2-BC1.R*.fastq
rm data/fecalRAD-BC2-BC2.R*.fastq
rm data/fecalRAD-BC2-BC3.R*.fastq
rm data/fecalRAD-BC2-BC7.R*.fastq
rm data/fecalRAD-BC2-BC8.R*.fastq
rm data/fecalRAD-BC3-BC1.R*.fastq
rm data/fecalRAD-BC3-BC2.R*.fastq
rm data/fecalRAD-BC3-BC3.R*.fastq
rm data/fecalRAD-BC3-BC4.R*.fastq
rm data/fecalRAD-BC3-BC5.R*.fastq
rm data/fecalRAD-BC3-BC6.R*.fastq
rm data/fecalRAD-BC4-BC3.R*.fastq
rm data/fecalRAD-BC4-BC4.R*.fastq
rm data/fecalRAD-BC4-BC5.R*.fastq
rm data/fecalRAD-BC4-BC6.R*.fastq
rm data/fecalRAD-BC4-BC7.R*.fastq
rm data/fecalRAD-BC4-BC8.R*.fastq

# ----------------------------------------------------------------------------------------
# --- Call make to process samples in individual mode
# ----------------------------------------------------------------------------------------

sed -e "s:READ1=.*:READ1=./data/\${IND_ID}.R1.fastq:g" -i config.mk
sed -e "s:READ2=.*:READ2=./data/\${IND_ID}.R2.fastq:g" -i config.mk
sed -e "s:GENOME_FA=.*:GENOME_FA=genomes/papAnu2/papAnu2.fa:g" -i config.mk
sed -e "s:GENOME_NAME=.*:GENOME_NAME=baboon:g" -i config.mk
sed -e "s:MAPQUAL=.*:MAPQUAL=0:g" -i config.mk
sed -e "s:MARK_DUPS=.*:MARK_DUPS=FALSE:g" -i config.mk

# Make list of individuals
ls data/*.fastq | cut -d"." -f1 | cut -d"/" -f 2 | sort | uniq > data/individual_list.txt

# ----------------------------------------------------------------------------------------

# Revert to old way of calling samtools
mv scripts/call_snps.sh scripts/call_snps_new_samtools.sh
sed -e "s/-ugf/-Auf/g" -e "s/call -vmO b/view -bvcg -/" \
	< scripts/call_snps_new_samtools.sh > scripts/call_snps.sh
chmod +x scripts/call_snps.sh

# ----------------------------------------------------------------------------------------

# Edit Makefile to have correct working directory path and Java module
sed -i "s:papionin_genomes/NGS-map-master:fecalRAD/NGS-map:" pbs/call_make.pbs
sed -i "s:jdk/1.7.0:jdk/1.7.0_60:" pbs/call_make.pbs

# Change path to bin
sed -i "s:~/bin:/home/cmb433/exome_macaque/bin:g" config.mk 

# Call make on all input files
NUM_IND=`wc -l data/individual_list.txt | cut -d' ' -f1`

qsub -t 1-${NUM_IND} pbs/call_make.pbs

# ----------------------------------------------------------------------------------------
# --- Profile samples with Kraken - Now skipped
# ----------------------------------------------------------------------------------------

cd /scratch/cmb433/fecalRAD/NGS-map/data
mkdir profiled_samples

module load metaphlan/2.0.0 
module load bowtie2/intel/2.2.3

fec_samples=`ls *.fastq`

for f in ${fec_samples}; do
    python ${METAPHLAN_ROOT}/metaphlan2.py \
        --mpa_pkl ${MPADB_DIR}/mpa_v20_m200.pkl \
        --bowtie2db ${MPADB_DIR}/mpa_v20_m200 \
        --bt2_ps very-sensitive \
        --input_type multifastq \
        --bowtie2out ${f}.bt2out > profiled_samples/${f}.metaphlan.txt
done

export PATH=$PATH:/home/cmb433/exome_macaque/bin/jellyfish-1.1.11/bin/bin/

module load kraken/intel/0.10.4

DBDIR=/scratch/cmb433/kraken_db
mkdir $DBDIR
DBNAME=${DBDIR}/kraken_db

# Build database
kraken-build --standard --threads 12 --db $DBNAME

kraken --db $DBNAME seqs.fa

# ----------------------------------------------------------------------------------------
# --- Downsample to equalize coverage in blood-feces pairs
# ----------------------------------------------------------------------------------------

# Do downsampling
perl ../RAD-faex/scripts/downsample_bloods.pl

# Fake the precursor files to get ready, and then call Make on these downsampled samples
perl ../RAD-faex/scripts/prepare_to_process_downsampled.sh

# Fix the headers in the BAM files
module load picard-tools/1.129
module load samtools

for BAM in results/*samp*.PE.bwa.baboon.passed.realn.bam; do
    cp ${BAM} ${BAM}.backup
    DS_ID=`echo $BAM | sed -e "s:results/::" -e "s/\.bwa.*//"`
    java -jar ${PICARD_TOOLS_ROOT}/picard.jar AddOrReplaceReadGroups \
        INPUT=$BAM.backup \
        OUTPUT=$BAM \
        RGLB=${DS_ID} \
        RGPL=Illumina \
        RGPU=Group1 \
        RGSM=${DS_ID}
    samtools index $BAM
done

# ----------------------------------------------------------------------------------------
# --- Do multi-sample SNP calling and filtration
# ----------------------------------------------------------------------------------------

cd /scratch/cmb433/fecalRAD/NGS-map

# Move "NOTHING" samples
mkdir results/nothing_samples
mv results/NOTHING* results/nothing_samples/

# ----------------------------------------------------------------------------------------

# Add email address to PBS file
sed -i '/-N gatk_genotype/a#PBS -M cmb433@nyu.edu' pbs/call_gatk_genotyper.pbs
sed -i "s:jdk/1.7.0:jdk/1.7.0_60:" pbs/call_gatk_genotyper.pbs

# Perform multi-sample SNP-calling, one job per chromosome (this includes X as "21")
qsub -t 1-21 pbs/call_gatk_genotyper.pbs

# ----------------------------------------------------------------------------------------

# Filter SNPs

# PBS file has been added to repo, so it's already in pbs/

# Add email address to PBS file
sed -i '/-N filter_gatk_snps/a#PBS -M cmb433@nyu.edu' pbs/filter_gatk_snps.pbs
sed -i "s:jdk/1.7.0:jdk/1.7.0_60:" pbs/filter_gatk_snps.pbs

# Filter SNPs (This used to be for only autosomes. Changed to 1-21 to do X too.)
qsub -t 1-21 pbs/filter_gatk_snps.pbs

# ----------------------------------------------------------------------------------------

# Call pipeline in comparison mode to merge multi-sample SNPs, convert VCF file to PED,
# and make binary PED (BED)

make -s -f full_analysis.mk compare

# ----------------------------------------------------------------------------------------

# Rename folder of SNPs to indicate that these were called in multi-sample SNP mode
mv baboon_snps{,_multi}

mv baboon.pass.snp.* baboon_snps_multi/

# ----------------------------------------------------------------------------------------
# --- Now call GATK to generate SNP sets that are NOT called in multi-sample mode
# ----------------------------------------------------------------------------------------

# Copy in GATK-individual-mode PBS script from the other repo
cp ../RAD-faex/pbs/call_gatk_genotyper_indiv.pbs pbs/

qsub -t 1-21 pbs/call_gatk_genotyper_indiv.pbs

# Clean up
rm baboon_snps/*tmp*

# Replace QUAL score of "inf" with one more than the maximum QUAL score found
###sh ../RAD-faex/scripts/replace_inf_in_indiv_vcfs.sh

# Clean up some more
rm baboon_snps/chr*.INDIV.raw.snps.indels.vcf_BACKUP

# And filter
cp ../RAD-faex/pbs/filter_gatk_snps_indiv.pbs pbs/
qsub -t 1-21 pbs/filter_gatk_snps_indiv.pbs

###	# Fix headers
###	# Get rid of, e.g., chr10.raw.snps.indels.tmp12_
###	# And replace it with info on sample used to determine downsampling level
###	BAMS=(`ls results/*.PE.bwa.baboon.passed.realn.bam`)
###	
###	# Downsampled samples to fix
###	DS_SAMPS=($(grep "^#CHROM" baboon_snps/chr20.INDIV.pass.snp.vcf | \
###	    tr "\t" "\n" | grep "chr" | sed -e "s/chr20/chr[0-9]\*/"))
###	
###	for ((i=0; i < ${#DS_SAMPS}; i++)); do
###	
###	    if [[ ${DS_SAMPS[$i]} = *[!\ ]* ]]; then
###	    	REPLACEE=${DS_SAMPS[$i]}
###	        echo "    Replacing ${DS_SAMPS[$i]}..."
###	        DS_IDX=`echo ${DS_SAMPS[$i]} | sed -e "s/.*tmp\([0-9]*\).*/\1/"`
###	        echo "    ...with item indexed ${DS_IDX}...";
###	        REPLACER=`echo ${BAMS[$DS_IDX - 1]} | sed -e "s/.*fecalRAD/fecalRAD/" -e "s/\.PE.*//"`
###	        echo "    ...with ${REPLACE}.";
###	        
###	        for file in baboon_snps/chr*.INDIV.pass.snp.vcf; do
###	            sed -e "s/$REPLACEE/$REPLACER/g" -i $file
###	        done
###	    fi
###	done

# Steal steps from make to merge multi-sample SNPs, convert VCF file to PED,
# and make binary PED (BED)

# Merge non-multi-sample SNPs (autosomes only)
module load vcftools
vcf-concat baboon_snps/chr[0-9]*.INDIV.pass.snp.vcf | \
    gzip -c > baboon_snps/baboon.INDIV.pass.snp.vcf.gz

# Convert VCF file to PED
vcftools --gzvcf baboon_snps/baboon.INDIV.pass.snp.vcf.gz --plink \
    --out baboon_snps/baboon.INDIV.pass.snp

# Edit the MAP file (baboon.pass.snp.map) and get rid of the "chr"
# VCF uses, e.g., "chr10" whereas plink wants just "10"
sed -i -e 's/^chr//' baboon_snps/baboon.INDIV.pass.snp.map

# Make binary PED file
module load plink
plink --noweb --file baboon_snps/baboon.INDIV.pass.snp --make-bed \
    --out baboon_snps/baboon.INDIV.pass.snp

# ----------------------------------------------------------------------------------------

# Rename folder of SNPs to indicate that these were called in non-multi-sample SNP mode
mv baboon_snps{,_indiv}

# Move on to commands in RADfaex_cmds.sh
