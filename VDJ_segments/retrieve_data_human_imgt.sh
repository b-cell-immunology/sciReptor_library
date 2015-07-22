#!/usr/bin/bash
export SOURCE="imgt"
export SPECIES="human"
export CURR_DATE=$(date --iso-8601)
export BASE_URL="http://www.imgt.org/genedb"

declare -A HASH_BINOM;
HASH_BINOM["human"]="Homo+sapiens";
HASH_BINOM["mouse"]="Mus+musculus";

if ! (type "curl" > /dev/null);
then
	echo "FATAL: Could not find \"curl\" transfer client! Aborting!"
	exit 1;
fi;

OUT_DIR="data_${SOURCE}_${SPECIES}_${CURR_DATE}"
if [[ -d "$OUT_DIR" ]];
then
	echo "ERROR: Data directory $OUT_DIR already exists"
	exit 1
else 
	mkdir "$OUT_DIR"
fi;

OUT_FILE_SEGINFO="segments_${SOURCE}_${SPECIES}_${CURR_DATE}.tsv"
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
	--output "${OUT_DIR}/${SPECIES}_gl_#1.html" \
	"${BASE_URL}/GENElect?query=7.2+IG{HV,HD,HJ,KV,KJ,LV,LJ}&species=${HASH_BINOM[${SPECIES}]}"

for SEGTYPE in V D J;
do
	OUT_FILE_FASTA="${OUT_DIR}/${SPECIES}_gl_${SEGTYPE}"
	touch $OUT_FILE_FASTA
	for LOCUS in H K L;
	do
		if [[ $SEGTYPE == "D" &&  (! $LOCUS == "H") ]];
		then
			continue
		fi;
		BASE_TEMP_FILE="${OUT_DIR}/${SPECIES}_gl_${LOCUS}${SEGTYPE}"
		tail -n +$(( $(grep -n "<b>Number of results =" ${BASE_TEMP_FILE}.html | sed "s/:.*//") + 1 )) ${BASE_TEMP_FILE}.html > ${BASE_TEMP_FILE}_2.html;
		head -n $(( $( grep -n -i -m 1 "^<hr\(\ \/\)\?>$" ${BASE_TEMP_FILE}_2.html | sed "s/:.*//" ) - 2 )) ${BASE_TEMP_FILE}_2.html > ${BASE_TEMP_FILE}_3.html;
		cat  ${BASE_TEMP_FILE}_3.html | tr "\12" "\00" | sed "s/.*<pre>\x00\([^<]\+\)\x00<\/pre>.*/\1/" | tr "\00" "\12" > ${BASE_TEMP_FILE}.fasta
 		grep -H "^>" ${BASE_TEMP_FILE}.fasta | sed "s/^${OUT_DIR}\/${SPECIES}_gl_\([HKL]\)\([VDJ]\)\.fasta:>[[:alnum:]_.]\+|\([^|]\+\)|.*/\3\t\2\1/" >> $OUT_FILE_SEGINFO
 		cat ${BASE_TEMP_FILE}.fasta | sed "s/^>[[:alnum:]_.]\+|\([^|]\+\)|.*/>\1/" >> $OUT_FILE_FASTA
		rm ${BASE_TEMP_FILE}*.html ${BASE_TEMP_FILE}.fasta;
	done;
	 makeblastdb -dbtype nucl -in $OUT_FILE_FASTA -parse_seqids
	 mv $OUT_FILE_FASTA ${OUT_FILE_FASTA}.fasta
done;

sync
IGDATA="../igdata/database"
cp $OUT_DIR/*.n* ${IGDATA}/
