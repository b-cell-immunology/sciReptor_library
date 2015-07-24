#!/usr/bin/bash
export SOURCE="igblast"
export SPECIES="mouse"
export CURR_DATE=$( date --iso-8601 )
export BASE_URL="ftp://ftp.ncbi.nih.gov/blast/executables/igblast/release/database"

TARGET_DIR=$1

declare -A HASH_BINOM;
HASH_BINOM["human"]="Homo+sapiens";
HASH_BINOM["mouse"]="Mus+musculus";

if ! (type "curl" > /dev/null);
then
	echo "FATAL: Could not find \"curl\" transfer client! Aborting!"
	exit 1;
fi;

OUT_DIR="data_${SPECIES}_${SOURCE}_${CURR_DATE}"
if [[ -d "$OUT_DIR" ]];
then
	echo "ERROR: Data directory $OUT_DIR already exists"
	exit 1
else 
	mkdir "$OUT_DIR"
fi;

OUT_FILE_SEGINFO="segments_${SPECIES}_${SOURCE}_${CURR_DATE}.tsv"
if [[ -e "$OUT_FILE_SEGINFO" ]];
then
	echo "ERROR: Segment information file $OUT_FILE_SEGINFO already exists"
	exit 1
else
	touch "$OUT_FILE_SEGINFO"
fi;

echo "Retrieving data from ${BASE_URL}"
curl \
	--location \
	--silent \
	--write-out "Retrieved %{filename_effective} (%{size_download} bytes)\n" \
	--output "${OUT_DIR}/${SPECIES}_gl_#1.#2" \
	"${BASE_URL}/${SPECIES}_gl_{V,D,J}.{nhr,nin,nog,nsd,nsi,nsq}"

if [[ $( blastdbcmd -version | grep "blastdbcmd" | sed "s/.*\.\([0-9]\+\)+$/\1/" ) -lt 30 ]];
then
	echo "FATAL: This script requires blastdbcmd version 2.2.30+ or above!" 1>&2
	echo "       Data was downloaded, but neither FASTA files nor segment"
	echo "       information has been generated! Aborting..."
	exit 1;
fi;

for SEGTYPE in V D J;
do
	echo "Processing $SEGTYPE segments..."
	OUT_FILE_FASTA="./data_${SPECIES}_${SOURCE}_${CURR_DATE}/${SPECIES}_gl_${SEGTYPE}.fasta"
	touch $OUT_FILE_FASTA
	blastdbcmd -db ./data_${SPECIES}_${SOURCE}_${CURR_DATE}/${SPECIES}_gl_${SEGTYPE} -entry all -outfmt "%i=%s" \
	| while read BLASTDBOUT;
	do
		if [[ ${BLASTDBOUT} =~ ([-./*#0-9A-Za-z]+)\=([[:alpha:]]+) ]];
		then
			BLAST_ID=${BASH_REMATCH[1]}
			BLAST_SEQ=${BASH_REMATCH[2]}
			printf ">%s\n%s\n" "$BLAST_ID" "$BLAST_SEQ" >> $OUT_FILE_FASTA
			printf "%s\t%s\n" "$BLAST_ID" "$SEGTYPE" >> $OUT_FILE_SEGINFO
		else
			echo "ERROR: Could not match BLASTDBOUT \"${BLASTDBOUT}\"" 1>&2
		fi;
	done;
done;
echo "WARNING: Only segment type (V, D or J), but NO LOCUS DATA (H, K or L) has been added to the output ($OUT_FILE_SEGINFO)." 1>&2

if [[ -n $TARGET_DIR ]];
	cp ${OUT_DIR}/*.n* ${TARGET_DIR}/
else
	echo "INFO: No target directory given. Copying of database files will be skipped." 1>&2
fi;
