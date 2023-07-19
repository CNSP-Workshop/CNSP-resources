----------------------------------------------------------------------------------------------------
--------------------------------------- DiliBach EEG dataset ---------------------------------------

Monophonic Bach music EEG Experiment from:
Di Liberto et al., Cortical encoding of melodic expectations in human temporal cortex, eLife, 2020

Please cite: https://datadryad.org/stash/dataset/doi:10.5061/dryad.g1jwstqmh

The EEG experiment was designed by Giovanni M. Di Liberto and Claire Pelofi
and conducted at the Laboratoire des Systèmes Perceptifs, UMR 8248, CNRS, Ecole Normale Supérieure,
PSL University, France.
Data were collected by Giovanni M. Di Liberto, Claire Pelofi, and Gaelle Rouvier
(See below for the list of authors and affiliations)

Version 1.2: 24 June 2021 - Giovanni M. Di Liberto

--- CND data ---------------------------------------------------------------------------------------

EEG signal was recorded as participants listened to monophonic piano Bach music.
Subjects 1-10 were non-musicians and 11-20 were expert pianists.
One Matlab (.mat) file for each subject. Each data file contains two variables: 'fs' (the sampling
frequency) and the EEG data.

EEG data were saved according to the CND data format (Continuous-events Neural Data format;
www.cnspworkshop.net/cndFormat.html). 

A single file is saved containing the stimulus data, which is the same across all subjects. This
file contains a variable 'stim' including, for example, stimulus features such as the speech
envelope.

A single file per subject contains the subject-specific EEG data. The experiment was grouped into
30 trials (each playing one of the ten available pieces). The 30 trials are collectively stored
using a cell array. The trial order is the same as in the 'stim' variable (so the same order
across participants), and it includes a variable indicating the original presentation order
for each subject.

Key variables and key fields in the CND structures:

*** dataStim.mat: Information and data that is common across subjects (in the CND format)
 stim.data{1,2}: speech envelope vectors for the second piece
 stim.data{2,5}: note onset vector for the fifth piece
 stim.data{3,5}: note onset vectors modulated by the absolute pitch value for the fifth piece
 stim.fs: Envelope signal sampling frequency


*** dataSub1.mat, ..., dataSubN.mat: Subject-specific EEG data (in the CND format)
 eeg.fs: EEG sampling frequency (512 Hz)
 eeg.data: cell array with the EEG signal for each of the 30 experimental trials (corresponding
           to the 30 cells in the dataStim.mat file. Each cell has size: timeSamples x channels
 eeg.chanlocs: channel location information
 eeg.extChan{1}.data: EEG external mastoid electrodes
 eeg.paddingStartSample: EEG data were time-locked to the onset of the speech stimulus for each
                         trial. However, note that a padding was added at the start and end of
                         each trial to allow the users to, for example, perform filtering and 
                         then remove side filtering artifacts if needed. Of course, this also
                         means that the first sample of the stimulus corresponds to the EEG
                         sample eeg.paddingStartSample+1 (=513).

notes:
 - There were 64 scalp channels + 2 mastoid electrodes (electrodes 65 and 66 correspond to left and
   right mastoids respectively);
 - Stimulus vectors were shared at fs=64Hz, as in Di Liberto et al., eLife, 2020. In addition, we
   have shared the original MIDI files used for the experiment (see below).

(TODO) Familiarity ratings

--- Stimuli ----------------------------------------------------------------------------------------
Original stimuli can be found on http://www.jsbach.net
and correspond to Bach violin pieces from sonatas and partitas, and partita for flute in A minor.

Audio files original filenames
audio1.mid - fp-1all.mid 
audio2.mid - fp-2cou.mid
audio3.mid - fp-3sar.mid
audio4.mid - fp-4bou.mid
audio5.mid - vp2-1all.mid
audio6.mid - vs1-4prs.mid
audio7.mid - vp1-1al_v2.mid
audio8.mid - vp2-4gig_v2.mid
audio9.mid - vp3-2lou.mid
audio10.mid - vp3-3gav_v2.mid



---
List of authors: Giovanni M. Di Liberto[1], Claire Pelofi[2,3], Roberta Bianco[4], Prachi Patel[5,6], Ashesh D. Mehta[7], Jose L. Herrero[7], Alain de Cheveigné[1,4], Shihab Shamma[1,8], Nima Mesgarani[5,6]

1 Laboratoire des Systèmes Perceptifs, UMR 8248, CNRS, France. Ecole Normale Supérieure, PSL University, France
2 Department of Psychology, New York University, New York, NY, USA
3 Institut de Neurosciences des Système, UMR S 1106, INSERM, Aix Marseille Université, France
4 UCL Ear Institute, London, United Kingdom
5 Department of Electrical Engineering, Columbia University, New York, NY, USA
6 Mortimer B. Zuckerman Mind Brain Behavior Institute, Columbia University, New York, NY 10027, United States
7 Department of Neurosurgery, Zucker School of Medicine at Hofstra/Northwell and Feinstein Institute of Medical Research, Manhasset, NY 11030, United States
8 Institute for Systems Research, Electrical and Computer Engineering, University of Maryland, College Park, USA
