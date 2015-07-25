#!/usr/bin/bash
if [[ $1 == "" ]];
then
	echo "usage: proc_constant_loci <csv_file>"
	exit 1;
fi;

echo "Downloading constant segments..."

cat "$1" | \
while read CSVLINE; do
	BAK_IFS=$IFS;
	IFS=";"
	CSVARRAY=($CSVLINE)
	if [[ ${CSVARRAY[0]} == "species" ]];
	then
		continue
	fi;

	SPECIES=${CSVARRAY[0]}
	SEQNAME=${CSVARRAY[1]}
	SEQID=${CSVARRAY[2]}
	POSSTART=${CSVARRAY[4]}
	POSEND=${CSVARRAY[5]}

	if [[ ! -e ${SPECIES}_gl_C ]];
	then
		touch ${SPECIES}_gl_C.fasta
	fi;
	
	printf "%-12s: " "${SEQNAME}"

	echo ">${SEQNAME}" \
		>> ${SPECIES}_gl_C.fasta
	curl -# "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=${SEQID}&rettype=fasta&retmode=text" \
		| grep -v "^>.*" \
		| tr -d "\12" \
		| cut -c${POSSTART}-${POSEND} \
		| sed "s/\(.\{1,60\}\)/\1\n/g" \
		>> ${SPECIES}_gl_C.fasta
	IFS=$BAK_IFS;
done

# if ( command -v makeblastdb > /dev/null 2>&1 );
# then
# 	mkdir -p database
# 	ls -1 *_gl_C.fasta \
# 		| sed "s/\.fasta//" \
# 		| xargs -n 1 -I '{}' makeblastdb -dbtype nucl -parse_seqids -in '{}'.fasta -out database/'{}'
# else
# 	echo "makeblastdb not available, skipping database build."
# fi;
