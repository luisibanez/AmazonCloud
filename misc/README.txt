###################
## NY-Albany.AMI ##
###################



SYSTEM PREREQUISITES
===============================================================================================

1. Linux software Requirements  

 Use the AMI ID ami-edeb4384 to launch an instance on Amazon Cloud 
 Use m1.large so you can run bwa on mutliple cores

 Once the instance is up and running, login to the instance, do the following:

  >. sudo apt-get update 
  >. sudo apt-get install gcc
  >. sudo apt-get install make
  >. sudo apt-get install git 



2. Install Python
  
  >. sudo apt-get install zlib1g-dev
  >. sudo ln -s /lib/x86_64-linux-gnu/libz.so.1 /lib/libz.so
  >. wget http://www.python.org/ftp/python/2.7.3/Python-2.7.3.tar.bz2
  >. tar -xvf Python-2.7.3.tar.bz2
  >. cd Python-2.7.3
  >. ./configure 
  >. make 
  >. sudo make install



3.  install Numpy 
  >. git clone git://github.com/numpy/numpy.git numpy
  >. cd numpy
  >. sudo python setup.py build
  >. sudo python setup.py install



TOOL SETUP and SHARE MOUNT
===============================================================================================

1. setup modENCODE tools for alignments and peak calls
  >. cd /modencode
  >. wget http://data.modencode.org/modENCODE_Galaxy/tarballs/tools.tar
  >. tar xvf tools.tar 


2. And set your environments
  >. cd /modencode/tools  
  >. . env.sh 


3. Mount data to server. 
   commands to mount and insgtall client
  >. mount `ec2.domain.instance.com`:/mnt/data /mnt/data 
     (`ec2.damin.instance.com` will be updated with NFS master server's URL)

4. Prepare some system environment variables
  >. ANALYSIS_DIR="/mnt/data"
  >. sudo mkdir $ANALYSIS_DIR
  >. cd $ANALYSIS_DIR
  >. sudo chown ubuntu:ubuntu $ANALYSIS_DIR



DOWNLOAD and CONVERT INPUT DATA: FASTQ, FASTA, BAM, SAI, SAM
===============================================================================================

1. Make fastq directory
  >. mkdir $ANALYSIS_DIR/fastq ; cd $ANALYSIS_DIR/fastq

2. Test data set 1
    # For now, get them from the ftp site
    * Students will get them from the 1TB snapshot
    * NOTE: ftp.modencode.org is actually running on Amazon Cloud 
  >. wget ftp://ftp.modencode.org/all_files/cele-raw-1/3066_Snyder_GEI-11_GFP_L3_rep1.fastq.gz
  >. wget ftp://ftp.modencode.org/all_files/cele-raw-1/3066_Snyder_GEI-11_Input_L3_rep1.fastq.gz
  >. wget ftp://ftp.modencode.org/all_files/cele-raw-1/3066_Snyder_GEI-11_GFP_L3_rep2.fastq.gz
  >. wget ftp://ftp.modencode.org/all_files/cele-raw-1/3066_Snyder_GEI-11_Input_L3_rep2.fastq.gz

3. Make fasta directory
  >. mkdir $ANALYSIS_DIR/fasta; cd $ANALYSIS_DIR/fasta

4. Download worm reference genome
  >. wget http://data.modencode.org/modENCODE_Galaxy/Test_Data/fasta/WS220.fasta

5. use bwa to index the worm genome - for information on bwa commands, see http://bio-bwa.sourceforge.net/
  >. bwa index -a is WS220.fasta 

6. Make bam directory 
  >. mkdir $ANALYSIS_DIR/bam  ; cd $ANALYSIS_DIR/bam 

7. Prepare .sai files
     # Students should use at least m1.large so they can do the alignment on multiple cores 
     # alignment using two threads ( -t 2 ) 
     # output of alignment is in sai format 
  >. for i in `ls $ANALYSIS_DIR/fastq/*gz`; do echo ; echo "bwa aln -t 2 $ANALYSIS_DIR/fasta/WS220.fasta $i > `basename $i`.sai"; done 

8. Convert sai to sam format
     # see http://samtools.sourceforge.net/SAM1.pdf
  >. for i in `ls *.sai`; do echo ; fq=`basename $i .sai`; echo "bwa samse $ANALYSIS_DIR/fasta/WS220.fasta $i $ANALYSIS_DIR/fastq/$fq > ${i}.sam "; done 


9. Convert sam to bam 
  >. for i in `ls *.sam`; do echo ; echo "samtools view -Sbo ${i}.bam $i "; done 



EXECUTE COMMANDS
===============================================================================================

1. Make output directory
  >. mkdir ${ANALYSIS_DIR}/macs2_output; cd ${ANALYSIS_DIR}/macs2_output

2. Call peaks with macs2 - see https://github.com/taoliu/MACS/
     # rep1
  >. macs2 callpeak -t ../bam/3066_Snyder_GEI-11_GFP_L3_rep1.fastq.gz.sai.sam.bam  -c ../bam/3066_Snyder_GEI-11_Input_L3_rep1.fastq.gz.sai.sam.bam -f BAM -g ce -n rep1  -B -q 0.01

     # rep2 
  >. macs2 callpeak -t ../bam/3066_Snyder_GEI-11_GFP_L3_rep2.fastq.gz.sai.sam.bam  -c ../bam/3066_Snyder_GEI-11_Input_L3_rep2.fastq.gz.sai.sam.bam -f BAM -g ce -n rep2  -B -q 0.01




OTHERS
===============================================================================================

* other things students can do:
  - Use Unix commands to count the number of reads in all the FASTQ files - see http://en.wikipedia.org/wiki/FASTQ_format.  Each entry in the FASTQ file consists of 4 lines so technically, students can just count the number of lines and divides by 4.  
  - write a small program to count the number of A,C,G,T bases in the worm genome.  The worm genome is in FASTA format - see http://en.wikipedia.org/wiki/FASTA_format.  Students can write his/her program in any language
  - count the number of reads aligned to the worm genome.  Use samtools to achive this 
    samtools view -f 0x0004 bam.file | wc -l   





