#!/usr/bin/bash

export CURR_DATE=$( date --iso-8601 )
export LIBRARY="devel_library_mouse_ncbim38"
export DIR_IGDATA_MAIN="igdata"
export DIR_IGDATA_DATABASE="${DIR_IGDATA_MAIN}/database"
export DIR_FASTA_VDJ="VDJ_segments/data_mouse_ncbim38_${CURR_DATE}"
export DIR_FASTA_CONST="constant_segments/data_mouse_ncbim38_${CURR_DATE}"

if [[ ! -e $HOME/.my.cnf ]]; then
	echo "[build_library_mouse_ncbim38.sh][FATAL] Could not find MySQL/MariaDB local config file \"$HOME/.my.cnf\"."
	echo "   This file is required for providing authentication and connection information for database access. Aborting!"
	exit 1;
fi

if [[ $( makeblastdb -version | grep "makeblastdb" | sed "s/.*\.\([0-9]\+\)+$/\1/" ) -lt 30 ]];
then
	echo "[build_library_mouse_ncbim38.sh][FATAL] This script requires makeblastdb version 2.2.30+ or above. Aborting!" 1>&2
	exit 1;
fi;

# set up library database schemes
#
echo "[build_library_mouse_ncbim38.sh][INFO] Creating library database scheme \"${LIBRARY}\""
if (! mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb -e "CREATE SCHEMA IF NOT EXISTS ${LIBRARY};" );
then
	echo "[FATAL] Could not create library database scheme \"${LIBRARY}\". Aborting!" 1>&2
	exit 1;
fi;

echo "[build_library_mouse_ncbim38.sh][INFO] Creating tables for library database"
if (! mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${LIBRARY} < igdb_library.sql );
then
	echo "[FATAL] Could not create tables in library database. Aborting!" 1>&2
	exit 1;
fi;

mkdir -p "$DIR_IGDATA_DATABASE" "$DIR_FASTA_VDJ" "$DIR_FASTA_CONST"

# retrieve sequence data from ENSEMBL
#
for SEGTYPE in V D J;
do
	scripts/ensembl_retrieve.pl \
		--assembly=NCBIm38 \
		VDJ_segments/mouse_NCBIm38_Ig?-${SEGTYPE}_pos.csv \
		> ${DIR_FASTA_VDJ}/mouse_gl_${SEGTYPE}.fasta
done

# Build IgBLAST database
#
for SEGTYPE in V D J;
do
	makeblastdb \
		-dbtype nucl \
		-in ${DIR_FASTA_VDJ}/mouse_gl_${SEGTYPE}.fasta \
		-out ${DIR_IGDATA_DATABASE}/mouse_ncbim38_gl_${SEGTYPE} \
		-title mouse_ncbim38_gl_${SEGTYPE} \
		-parse_seqids
done

echo "[build_library_mouse_ncbim38.sh][INFO] Setting up database for mouse NCBIm38 VDJ sequences"
cd VDJ_segments
./build_VDJ_db.pl \
	-mysql_group mysql_igdb \
	-lu segments_mouse_ncbim38_2015-05-14.tsv \
	-sp mouse \
	-fa_dir ../$DIR_FASTA_VDJ \
	-lib_scheme $LIBRARY \
	-opt_file ../${DIR_IGDATA_MAIN}/optional_file/mouse_ncbim38_gl.aux \
	-log \
	-parse
cd ..

#constant segments
#
echo "[build_library_mouse_ncbim38.sh][INFO] Setting up database for mouse NCBIm38 constant sequences"
scripts/ensembl_retrieve.pl \
	--assembly=NCBIm38 \
	constant_segments/mouse_NCBIm38_Ig-C_pos.csv \
	> ${DIR_FASTA_CONST}/mouse_gl_C.fasta

makeblastdb \
	-dbtype nucl \
	-in ${DIR_FASTA_CONST}/mouse_gl_C.fasta \
	-out ${DIR_IGDATA_DATABASE}/mouse_ncbim38_gl_C \
	-title mouse_ncbim38_gl_C \
	-parse_seqids

constant_segments/build_constant_db.pl \
	-mysql_group mysql_igdb \
	-lib ${LIBRARY} \
	-sp mouse \
	-fasta ${DIR_FASTA_CONST}/mouse_gl_C.fasta \
	-parse

# process tags
#
cd tags
./process_tags.pl
cd ..

# Insert remaining tables into the database
#
echo "[build_library_mouse_ncbim38.sh][INFO] Setting up other databases (species, plate layout, tags)."
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${LIBRARY} --local_infile=1 < load_lib_tables.sql
