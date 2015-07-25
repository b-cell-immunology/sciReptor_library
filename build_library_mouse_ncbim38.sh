export CURR_DATE=$( date --iso-8601 )
export LIBRARY="library_mouse_ncbim38"
export DIR_IGDATA_DB="igdata/database"

if [[ ! -e $HOME/.my.cnf ]]; then
	echo "Could not find MySQL/MariaDB local config file \"$HOME/.my.cnf\". This file is required for providing"
	echo "authentication information to the script. Aborting!"
	exit 1;
fi

mkdir -p $DIR_IGDATA_DB

# set up library schemes
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb -e "CREATE SCHEMA IF NOT EXISTS ${LIBRARY};"
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${LIBRARY} < igdb_library.sql

# process mouse VDJ segment data 
#
cd VDJ_segments

for file in data_mouse_ncbim38_2015-05-14/mouse*.n*; 
	do cp -i "${file}" "${file/mouse_gl/mouse_ncbim38_gl}";		# Copy and rename"
done
mv -v data_mouse_ncbim38_2015-05-14/mouse_ncbim38*.n* ../${DIR_IGDATA_DB}

echo "[OK] Setting up database for NCBI m38 mouse VDJ."
./build_VDJ_db.pl \
	-mysql_group mysql_igdb \
	-lu segments_mouse_ncbim38_2015-05-14.tsv \
	-sp mouse \
	-fa_dir data_mouse_ncbim38_2015-05-14 \
	-lib_scheme ${LIBRARY} \
	-opt_file ../${DIR_IGDATA_DB}/../optional_file/mouse_ncbim38_gl.aux \
	-log \
	-parse

#constant segments
#
cd ../constant_segments/

echo "[OK] Setting up database for mouse constant."
cp -v mouse_ncbim38_gl_C.fasta ../${DIR_IGDATA_DB}/mouse_ncbim38_gl_C
makeblastdb -dbtype nucl -in ../${DIR_IGDATA_DB}/mouse_ncbim38_gl_C
mv -v ../${DIR_IGDATA_DB}/mouse_ncbim38_gl_C ../${DIR_IGDATA_DB}/mouse_ncbim38_gl_C.fasta
./build_constant_db.pl \
	-mysql_group mysql_igdb \
	-lib ${LIBRARY} \
	-sp mouse \
	-fasta ../${DIR_IGDATA_DB}/mouse_ncbim38_gl_C.fasta \
	-parse

# process tags
#
cd ../tags
./process_tags.pl

cd ..

# Insert remaining tables into the database
#
echo "[OK] Setting up other databases (species, plate layout, tags)."
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${LIBRARY} --local_infile=1 < load_lib_tables.sql
