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

srun -n $SLURM_NTASKS --mpi=pmi2 apptainer exec ${IMAGE} bash -c "source /opt/start.sh && cp2k.psmp -i /opt/uio/my_input.inp > /opt/uio/cp2k-output.${SLURM_JOBID}"
