Library building routines for the sciReptor toolkit
---------------------------------------------------

This set of scripts builds and installs the reference libraries (both internal
and BLAST) required by sciReptor. It additionally sets up metadata tables
required for processing of matrix scPCR data.

#####Used reference sequence libraries
1. _Mus musculus_, as provided by IgBLAST
2. _Homo sapiens_, as provided by  IMGT
3. _Mus musculus_ (C57BL/6 strain), an own manual build based on the NCBIm38
   assembly as provided by Ensembl.

Please note that libraries 1 and 2 are **not** included in this repo but will
be downloaded from their respective sites upon build, to ensure that you
will install the most recent version.

Library 3 is a complete reference library for the C57BL/6 strain. It is based
on the NCBI mouse genome assemblies 37 and 38 and has been extensively 
cross-checked for accurate segment boundaries. It is provided as positional
reference to the NCBIm38 assembly, the actual sequence data will be downloaded
during the installation process.


###Installation

Please follow the steps described in the [sciReptor installation guide](https://github.com/b-cell-immunology/sciReptor/blob/master/INSTALLATION.md#installing-and-running-scireptor).

###Related repositories

- [sciReptor](https://github.com/b-cell-immunology/sciReptor) is the parental
  repository, which contains the code for the actual data processing pipeline.


###Copyright and License

#####Code

Copyright (2013-2016) Katharina Imkeller and Christian Busse.

sciReptor is free software: you can redistribute it and/or modify it under
the terms of the [GNU Affero General Public License][] as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

sciReptor is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
for more details.

You should have received a copy of the GNU Affero General Public License
along with sciReptor. If not, see <http://www.gnu.org/licenses/>.

[GNU Affero General Public License]:https://www.gnu.org/licenses/agpl.html

#####Mouse C57BL/6 database

Created and maintained (2009-2016) by Christian Busse, covered by
EU Directive 96/9/EC on the legal protection of databases.

This database is made available under the [Open Database License][]. Any
rights in individual contents of the database are held by WTSI/EBI, who
impose [no restrictions][] on its use.

[Open Database License]: http://opendatacommons.org/licenses/odbl/1.0/
[no restrictions]: http://www.ensembl.org/info/about/legal/disclaimer.html
