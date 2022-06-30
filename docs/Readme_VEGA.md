# Building GEMINI on the ERAU HPC system

GEMINI must be built from a session on the login node as it requires git. The build system will not work in an interactive or queue session.

Load the necessary modules (cmake, gcc8, and openmpi):

```bash
module load gcc/8.3.0
module load openmpi/gcc8/64/3.1.2
module load python/3.9.2
```

Cmake version that compiles the latest gemini releases is 3.23.2. It is installed on Vega and can be linked from ```/cm/shared/apps/cmake/3.23.2/bin/cmake```

Make sure that next variables are specified in this particular way (future GEMINI releases may fix this, but current stable compilation is performed with this configuration):
```
export CXX=g++
export CC=gcc
export FC=gfortran
export F77=
export CXXCPP=
```

First, clone the externals repository:
```
git clone https://github.com/gemini3d/external.git
```

Navigate to the ./external/cmake/ folder and make sure that ```h5fortran tag``` is set as ```4.4.4``` in ```libraries.json```.

Then, build the externals using commands:
```
/cm/shared/apps/cmake/3.23.2/bin/cmake -B external/build -S external -DCMAKE_INSTALL_PREFIX=/scratch/username/libgem
/cm/shared/apps/cmake/3.23.2/bin/cmake --build external/build
```
Folder ```libgem``` can be placed in any directory. Make sure you specify the paths to this folder in the identical way at all steps. Consider specifying full path to the ```libgem``` folder.

Set environment variables
```
export CMAKE_PREFIX_PATH=/scratch/username/libgem
export PATH=$HOME/libgem/bin:$PATH
```

where ```CMAKE_PREFIX_PATH``` is a path to your ```libgem``` folder.

Clone the core GEMINI repository:

```bash
git clone https://github.com/gemini3d/gemini3d.git
```

Navigate into the source code directory and compile the code as:

```
cd gemini3d
/cm/shared/apps/cmake/3.23.2/bin/cmake -B build -DCMAKE_PREFIX_PATH=/scratch/username/libgem
/cm/shared/apps/cmake/3.23.2/bin/cmake --build build --parallel
```

A full compile will take approximate 5-10 minutes depending on which packages need to be compiled; you will see lots of warnings but these can be safely ignored. Executables are placed in the ```build``` directory and can be run from there.

In case ```HWM-14``` is required, first go to the ```/gemini3d/src/CMakeLists.txt```, and directly specify the path to HWM-14 folder from your ```libgem```, changing next lines as:
```
set(hwm14_data_dir /scratch/username/libgem/share/data/hwm14)
  set(hwm14_RESOURCE_FILES
  /scratch/username/libgem/share/data/hwm14/hwm123114.bin
  /scratch/username/libgem/share/data/hwm14/dwm07b104i.dat
  /scratch/username/libgem/share/data/hwm14/gd2qd.dat
  )
```

Then, compile code in ```/gemini3d/``` with flag as shown below:
```
/cm/shared/apps/cmake/3.23.2/bin/cmake -B build -DCMAKE_PREFIX_PATH=/scratch/username/libgem -Dhwm14=on
/cm/shared/apps/cmake/3.23.2/bin/cmake --build build --parallel
```


## Running GEMINI on the ERAU HPC

For a simulation not needing more than 256 GB of memory, 36 cores, and less than 24 hours of runtime, one should use an interactive session.  This can be obtained by logging into VEGA and then doing:

``` bash
qsub -I -l walltime=24:00:00 -l nodes=1:ppn=36
```

For longer or more expensive simulations you will need to use the queueing system, which requires a script that runs the code to be placed in the build directory where executables reside.  An example of such a script is shown below:

```text file
#!/bin/bash
# This is comment
#PBS -q longq
#PBS -l walltime=120:00:00
#PBS -l nodes=10:ppn=36
#PBS -N GEMINI_mooreOK
# Not necessary to set wall time,
# longq: 168 hours, 10 nodes (with 36proc for each), maximum 1 longq in queue per user
# normalq: 24 hours, 10 nodes, maximum 4 normalq in queue per user

# In you want to send job status to e-mail:
#PBS -M zettergm@erau.edu
#PBS -m aeb
cd $PBS_O_WORKDIR

#PBS -e /scratch/zettergm/GEMINI3D/pbs_errors.out
#PBS -o /scratch/zettergm/GEMINI3D/pbs_output.out

# Load modules during job submission!
module load gcc/8.3.0
module load openmpi/gcc8/64/3.1.2

# Run the program
mpirun -np $PBS_NP ./gemini.bin ../simulations/mooreOK3D_hemis_medres_corrected_control/ -manual_grid 36 10 -debug
```

This simulation runs an example "mooreOK3D_hemis_medres" using 360 cores split in a process grid of 36x10 in the x2 and x3 directions.

## Data management on the ERAU HPC

Once simulations are completed they need to be moved into your home directory, which is for long-term storage and has a 10 TB quota.  Output data can also be downloaded for postprocessing and plotting as needed; "rsync" is probably the best utility for this (comes standard on unix-likes macOS and Linux).  E.g. if you navigate to the directory on your local computer where you want to store the data (~/simulations in this example) you can copy data from remote VEGA directory ~/vega_simulations/testdata to your computer via:

```bash
cd ~/simulations/
rsync -av --progress username@vega.erau.edu:vega_simulations/testdata ./
```

A benefit of using rsync is that if the data transfer is interrupted (bad connection) you can reissue the same command again and it will pick up where it left off and not unnecessarily transfer files it has already completed.
