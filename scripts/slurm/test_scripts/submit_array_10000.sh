#!/bin/bash

sbatch --array=1-10000 --mem=10M --wrap='for i in {1..2}; do echo "Task $SLURM_ARRAY_TASK_ID - Count $i"; sleep 1; done'