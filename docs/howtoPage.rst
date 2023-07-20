How-to Guides 
=============

This page contains a number of practical guides for setting up and using the CNSP resources.

This guide details the requirements and key steps for setting up the the CNSP resources on your computer.
The core component of the libraries and tutorials requires MATLAB software. We also include Python tutorials
and aim to add more in the future. Part of the resources are independent on a specific programming language (e.g., GUI).

Getting started - MATLAB
------------------------
This section will guide you through the process of setting up the CNSP core resources using MATLAB software.
You should have the MATLAB environment already installed on your computer (>2019, with the Signal Processing Toolbox).

First, let's set set up the CNSP starting package. This includes: a) the project folder structure;
b) the up-to-date libraries; and c) example scripts. We can't stress enough the importance of utilising the folder structure
and the file naming convention as indicated below. Inconsistencies will require unwanted changes to the scripts.

Download starter-kit `here <https://github.com/CNSP-Workshop/CNSP-resources/tree/main/CNSP>`_.
Please note that the libraries contain slim versions of dependencies such as EEGLAB
(used for the spline interpolation and topopolot functions),
the mTRF-Toolbox (used for the TRF method), and NoiseTools (used for the CCA method). Each folder contains the specific licence
and references for the corresponding library. 

.. image:: images/folderStructure.png
  :width: 200
  :alt: Alternative text

