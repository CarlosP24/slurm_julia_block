# Slurm Julia Block
Basic building block for julia multi-core paralellization in a slurm cluster.

Once set up just run

````
bash job.slurm ARG1 ARG2
````

## Usage
### Slurm manager
All code should be run in the cluster's access node.
Make sure you have passwordless access from it to all other nodes.

SLURM parameters are set through the header of job.slurm. Use sbatch parameters as needed.
The ones in this example are the most common:
- `#SBATCH -p partition_name` chooses the cluster partition you wanna use. `esbirro` shares access with `fiona`, so you can use `fiona`, `esbirro` or `all`.
- `#SBATCH --nodes=node_number` sets the number of nodes to use in your calculation. `esbirro` and `fiona` have 8 nodes each (use max 7, es1 and f1 should be free)
- `#SBATCH --nodes=acces_node` tells sbatch not to use the access node for calculations.
- `#SBATCH --exclusive` tells slurm to run only our calculation in that node.
- `#SBATCH --output=path` sets the path to send code output.
- `#SBATCH --error=path` sets the path to send code error messages.
- `#SBATCH --job-name=$2`changes the job name (that appears on `squeue` and so on) to an argument.

There are far many more SBATCH options and you might need them from time to time, check them out [here](https://slurm.schedmd.com/sbatch.html).
This code also writes the node list to machinefile to be used by the julia code (see below).

### Julia header
Your julia calculation should start as in MWE.jl. Apart from the usings and includes, it writes the nodelist and wished workers in an understandable way for Distributed.jl.
It is set to choose the number of workers per node automatically, change it if it does not work properly.

Don't forget to manually close your nodes at the end of the code. Esbirro might crash if not.

