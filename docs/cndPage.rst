CNSP CND data structure
#######################



The CND structure (Continuous-event Neural Data) is a domain specific  data format defined to encourage standardisation, replicability, and reusability of the code. 
The CND format will make your life easier during the CNSP workshop. Here are three reasons to adopt the CND data structure:

#. By converting your data to CND, you will be able to run the CNSP-Workshop analysis scripts without changes. While this will be very useful when using CNSP resources, it is also an opportunity to make your future code reusable across projects;
#. This will facilitate the comparison of a particular analysis procedure on different datasets (e.g., envelope TRFs from the music and speech datasets just by changing one line of code) and, vice versa, to compare different analysis pipelines on the same dataset;
#. Standardisation will facilitate collaboration between research teams and, in the context of the CNSP-Workshop, it will allow us to answer your questions more rapidly and effectively.



How to save your dataset in CND 
===============================

A set folder structure is provided for containing all the experimental files, and is organised into ‘code’, ‘tutorials’, ‘datasets’, and ‘libs’ (libraries) folders (Fig 1).  
For simplicity, we advise users to have one main folder for each study. Within the dataset folder there is a ‘dataCND’ folder, containing as many ‘dataStimX.mat’ 
(stimulus files) and ‘dataSubX.mat’ (neural data) files as the number of participants. If all subjects were exposed to  the same identical stimuli, then a single ‘dataStim.mat’ file can be used (Fig 2). 

.. image:: images/cnspMainFolderStructure.png
  :width: 300
  :alt: The CNSP folder structure


.. image:: images/exampleCNDLayout.png
  :width: 450
  :alt: The datasets folder structure



Example conversion script (bdf to cnd)
======================================
It is straightforward to convert your own dataset from the popular BIDS format to CND, using the bids2cnd function :download:`here <files/Read_bdf.m>`. The example script 
found :download:`here <files/bdf2CND_example2023.m>` can be used by changing the dataset to your own. 

