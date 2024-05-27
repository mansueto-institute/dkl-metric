# DKL Spatial Selection

This repository contains all the code to manipulate the data and create maps for the DKL for Spatial Selection paper. The main folder in this repository that contains all relevant scripts to calculate DKL and produce figures at the block group level for all MSAs in the US is at the `one-way-dkl/all_states_block/` path.

The repository is organized in the following way:

`archive/`: Old code files that may or may not be useful

`nicos_code/`: Scripts written by Nico. These are the original scripts from which the main scripts in the `one-way-dkl/` folder come from.

`one-way-dkl/`: This is the main folder in this repository. Within it, there is:
* `all_states_block/`: Contains all the scripts used to produce DKL calculations and figures at the block group level for all states in the USA. This folder also contains scripts to reproduce the results from the 2010 paper, and produce results for 2015 and 2020. This is the main folder with the bulk of the work for the paper.
* `chicago_block/`: Contains scripts used to produce DKL calculations and figures at the block group level for the MSA Chicago is in.
* `chicago_tracts/`: Contains scripts used to produce DKL calculations and figures at the census tract level for the MSA Chicago is in.
* `data/`: Contains small intermediary data files for the Chicago analyses.

`outputs/`: This folder contains some of the old plots generated by Nico from the nicos_code folder scripts

For questions about this repository, contact ivannar@uchicago.edu.
