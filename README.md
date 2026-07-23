# CP2K on Olivia - container-based multi-node runs

## Container

The image is built automatically from the included `Dockerfile` by a GitHub Action
and published to GHCR. Pull it with Apptainer on Olivia:

```bash
apptainer pull cp2k.sif docker://ghcr.io/j34ni/cp2k:latest
```

This writes the image to `cp2k.sif` in your current directory.

The image ships CP2K 2026.1 compiled against a conda-forge MVAPICH 4.x stack,
with COSMA, ELPA, FFTW3, ScaLAPACK, LIBINT, LIBXC and HDF5.

### Included dependencies

- BLAS, LAPACK, ScaLAPACK
- MPI (MVAPICH 4.x with CXI/Slingshot support)
- LibXC, FFTW3, HDF5, COSMA, Libint2, ELPA

### Not included

- DFTD4, PLUMED, SIRIUS, LIBXSMM, Libvori, PEXSI, TBLITE, SpLA, MiMiC
- GPU acceleration

## Validation

A 14-image CI-NEB calculation on an H-ZSM-5 zeolite system (DFT, GAPW) was run
across 2 nodes with 504 MPI ranks (252 per node). Results were compared against
a successful reference run using the NRIS/CPU CP2K 2023.1 module on the same
cluster.

Final energies per image matched to better than 1e-10 Hartree across all images:

| Image | Container (Hartree)    | Reference (Hartree)    | Difference   |
|-------|------------------------|------------------------|--------------|
| 1     | -3518.65969829950245   | -3518.65969829947608   | 2.6e-11      |
| 2     | -3518.61179361030872   | -3518.61179361030008   | 8.6e-12      |
| 3     | -3518.54121584973609   | -3518.54121584974791   | 1.2e-11      |
| 4     | -3518.52094973082330   | -3518.52094973075737   | 6.6e-11      |
| 5     | -3518.57012480591811   | -3518.57012480587946   | 3.9e-11      |
| 6     | -3518.63530509073962   | -3518.63530509063366   | 1.1e-10      |
| 7     | -3518.66931684779911   | -3518.66931684777046   | 2.9e-11      |

Note that the container run was faster than the reference, on the same 2 nodes and 504 ranks. 

## How to run your own case

### 1. Set up your working directory

Put the container image, your input file, and all associated files (xyz, basis
sets, pseudopotentials, etc.) in the same directory:

```
my_job/
├── cp2k.sif
├── my_input.inp
├── img0.xyz ... imgN.xyz
└── cp2k-data/
```

### 2. Create a job script

```bash
#!/bin/bash
#SBATCH --job-name=cp2k_neb
#SBATCH --account=account_number
#SBATCH --time=01:30:00
#SBATCH --partition=large
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=252
#SBATCH --cpus-per-task=1
#SBATCH --output=cp2k-%j.out
#SBATCH --error=cp2k-%j.err

set -o errexit
set -o nounset

export OMP_NUM_THREADS=1
export OMP_PLACES=cores
export OMP_PROC_BIND=close

export UCX_POSIX_USE_PROC_LINK=n
export MPICH_CH4_NETMOD=ofi
export FI_PROVIDER=cxi
export APPTAINER_QUIET=1

# Required for MVAPICH 4.x at non-power-of-2 rank counts (e.g. 504)
export MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=recursive_doubling

IMAGE="${PWD}/cp2k.sif"
export APPTAINER_BIND="${PWD}:/opt/uio"

echo "Nodes:   ${SLURM_NODELIST}"
echo "Ranks:   ${SLURM_NTASKS}"

srun -n $SLURM_NTASKS --mpi=pmi2 apptainer exec ${IMAGE} bash -c \
    "source /opt/start.sh && cp2k.psmp -i /opt/uio/my_input.inp > /opt/uio/cp2k-output.${SLURM_JOBID}"
```

Replace `account_number` with your project account and `my_input.inp` with your
input file name. Adjust `--nodes` and `--ntasks-per-node` to fit your case.

### 3. Submit

```bash
cd my_job
sbatch job.sh
```

### 4. Check the output

```bash
# confirm clean termination
tail -5 cp2k-output.<jobid>
# should end with "PROGRAM STOPPED IN"

# check for errors
grep -i "error\|abort" cp2k-<jobid>.err

# extract final energies (for NEB)
grep "Total energy" *BAND*.out
```

## Notes

- The container uses `cp2k.psmp` (MPI+OpenMP binary) with `OMP_NUM_THREADS=1`,
  which is equivalent to the pure MPI `cp2k.popt` binary. Do not mix module
  loads with this job script; the container is fully self-contained.
- The `MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=recursive_doubling` setting works
  around a known assertion failure in MVAPICH 4.x when `MPI_Allreduce` is
  called with a message count smaller than the largest power-of-2 below the
  total rank count. This is required at 504 ranks and may be needed at other
  non-power-of-2 counts as well. It has no effect on correctness.
- If your input references files via relative paths, make sure all of them are
  present in the directory you bind-mount into the container (`${PWD}` in the
  script above).
