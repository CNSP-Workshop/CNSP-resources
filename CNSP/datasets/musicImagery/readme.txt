This folder contains the data from the paper: The Music of Silence. Part I: Responses to Musical Imagery Encode Melodic Expectations and Acoustics. 
The processessing has been made with a filering between 0.1Hz and 30Hz using Butterworth zero-phase filters and down-sampled to 64 Hz. Data were re-referenced to the average of all 64 channels and bad channels were removed and inteperpolated using spherical spline interpolation. The stimuli onsets that were closer than 500ms from a metronome beat were removes. 

EEG data were saved according to the CND data format (Continuous-events Neural Data format; www.cnspworkshop.net/cndFormat.html).

A single file is saved containing the stimulus data, which is the same across all subjects. This file contains a variable 'stim' including, the expectation signal over time as well as the acoustic envelope.

A single file per subject contains the subject-specific EEG data in a 'eeg' variable. The experiment was grouped into 88 trials (both conditions included) as a cell-array in the 'data' field. The trial order is stored in 'stimIdxs' field and the condition order in 'condIdxs'. Extra channels are stored in 'extChan' with the same structure as 'data'.

We also include a folder original_stim containing the audio presented during the experiment (left channel is the metronome), the midi files and the scores.

References using this dataset (last update 23 July 2021):
Marion G, Di Liberto GM, Shamma SA, The Music of Silence. Part I: Responses to Musical Imagery Encode Melodic Expectations and Acoustics. J. Neurosci, in press, 2021
Di Liberto GM, Marion G, Shamma SA, The Music of Silence. Part II: Music Listening Induces Imagery Responses. J. Neurosci, in press, 2021
Di Liberto GM, Marion G, Shamma SA, Accurate decoding of imagined and listened melodies. Frontiers in Neuroscience, accepted, 2021

A version of this dataset will be shared on Dryad in the coming days.

Please note that this dataset is protected under the BSD 3-Clause License (see LICENSE file for details)
