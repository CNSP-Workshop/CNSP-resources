How-to Guides 
#############

This page contains a number of practical guides for setting up and using the CNSP resources.

This guide details the requirements and key steps for setting up the the CNSP resources on your computer.
The core component of the libraries and tutorials requires MATLAB software. We also include Python tutorials
and aim to add more in the future. Part of the resources are independent on a specific programming language (e.g., GUI).

Getting started - MATLAB
************************
This section will guide you through the process of setting up the CNSP core resources using MATLAB software.
You should have the MATLAB environment already installed on your computer (>2019, with the Signal Processing Toolbox).

Folder structure
================
First, let's set set up the CNSP starting package. This includes: a) the project folder structure;
b) the up-to-date libraries; and c) example scripts. We can't stress enough the importance of utilising the folder structure
and the file naming convention as indicated below. Inconsistencies will require unwanted changes to the scripts.

.. image:: images/folderStructure.png
  :width: 200
  :alt: Folder structure
  
The up-to-date starter-kit is available `here <https://github.com/CNSP-Workshop/CNSP-resources/tree/main/CNSP>`_.
Please download the entire folder ('CNSP'). We suggest adding a folder names 'code', or 'code_projectName' if 
multiple projects will be carried out with these resources.
Please note that the libraries contain slim versions of dependencies such as EEGLAB
(used for the spline interpolation and topopolot functions),
the mTRF-Toolbox (used for the TRF method), and NoiseTools (used for the CCA method). Each folder contains the specific licence
and references for the corresponding library. The folder 'datasets' should only contains the datasets and, potentially,
their conversion scripts (e.g., bdf2cnd.m, bdf2bids).

Adding a dataset
================
Let's test if your workspace is ready to be used. To do so, you will need to add a dataset to your folder structure. If this
is the first time you do this, we suggest downloading the
`Natural Speech CND Dataset <https://www.data.cnspworkshop.net/data/datasetCND_LalorNatSpeech.zip>`_. This dataset was collected
by Edmund Lalor, Giovanni Di Liberto, and Michael Broderick, and it was utilised for a number of publications.
The dataset includes EEG data from N=19 individuals, who were presented with continuous speech from an audio-book
(see `<datasetsPage>`_ for further information). The CND dataset should be added to the dataset folder, as indicated in the figure above
i.e., `datasets/nauralSpeech/dataCND`.


Running an example script
=========================
You are now ready to test the first CNSP example script. Open `CNSP/exampleScrips/CNSP_example1_forwardTRF.m`.

This script is grouped in four parts:

#. Clearing workspace and adding path to dependencies
#. Preprocessing and analysis parameters
#. Preprocessing
#. Forward TRF analysis

Step 1, 2, and 4 will have to be run every time you use this script.
Insead, Step 3 (preprocessing) saves the preprocessing files, so it will only have to be run once
(or every time you want to change the preprocessing).

As a result you should obtain the figure below:

.. image:: images/resultExample1.png
  :width: 300
  :alt: Results example 1
  
If this is what you see, then you can use the CNSP resources now. Otherwise, please see the next section on troubleshooting.

Troubleshooting
===============

The guidelines above include code and the dataset for running `CNSP_example1_forwardTRF.m`. So, what could go wrong?

Typical issues include:
 
#. MATLAB doesn't give an error, but *nothing happens*: You may have copied the dataset into the wrong folder.
   Or you might have downloaded some other dataset. Note that the dataset name should be specified in 
   `CNSP/exampleScrips/CNSP_example1_forwardTRF.m`
   by modifying the following line (around line 38):
   
   .. code-block:: javascript
	 
	 dataMainFolder = '../datasets/LalorNatSpeech/';
   
   
#. MATLAB returns an *error*: Since all key dependencies are in the `lib` folder, there might be issues with the version of MATLAB.


Setting up your data
********************
This section will guide you through the process of setting up a new datase so that it can be analysed
with the CNSP resources using MATLAB scripts or a `GUI <guiPage>` that can be used without MATLAB.



Folder structure
================
First, let's set set up the CNSP starting package. This includes: a) the project folder structure;
b) the up-to-date lib