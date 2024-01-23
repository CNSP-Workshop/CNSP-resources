# Script to convert MEG-MASC from BIDS to CND format
# Article available at https://www.nature.com/articles/s41597-023-02752-5/
# Dataset available at https://osf.io/ag3kj/
# https://cnsp-workshop.github.io/website/index.html
# Author: Martin M. Winchester
# Last update: 8 December 2023
import naplib
import mne_bids
import os
import argparse
import numpy as np
import datetime
import hdf5storage
import json


def setup_dirs(root_path):
    if not os.path.exists(root_path):
        os.makedirs(root_path)
    if not os.path.exists(root_path+"/dataCND"):
        os.makedirs(root_path+"/dataCND")
    if not os.path.exists(root_path+"/Stimulus"):
        os.makedirs(root_path+"/Stimulus")


def transform_to_cnd(curr_bids_file, data, dt, run, session, suffix, chs, fs, ext_data, ext_channels):
    if not curr_bids_file:
        names = [entry['ch_name'] for entry in chs]
        locs_list = [entry['loc'] for entry in chs]
        transposed_locs = list(map(list, zip(*locs_list)))
        chs_dict = {'name': names, **{f'locs{i}': locs for i, locs in enumerate(transposed_locs, start=1)}}

        # Chanlocs left in wrong format. To transform into correct format run 'eeg.chanlocs=[eeg.chanlocs{:}]' in MATLAB after loading
        list_length = len(next(iter(chs_dict.values())))
        list_of_dicts = [{key: chs_dict[key][i] for key in chs_dict} for i in range(list_length)]
        chs_df = list_of_dicts
        cnd_file = {"dataType": dt.upper(), "chanlocs": chs_df, "fs": fs, "data": data,
                    "extChan":[{"description": ext_channels[a]['ch_name'], "data": [np.moveaxis(bb[:, np.newaxis], 0, 1) for bb in b]} for a, b in enumerate([a for a in np.moveaxis(np.stack(ext_data), 2, 0)])]}
        if run:
            cnd_file["runs"] = [run]*len(cnd_file["data"])
        if session:
            cnd_file["sessions"] = [session]*len(cnd_file["data"])
        if suffix:
            cnd_file["suffixes"] = [suffix]*len(cnd_file["data"])
    else:
        cnd_file = curr_bids_file
        cnd_file["data"] += data

        for elec in range(len(cnd_file["extChan"])):
            elec_wise_data = [np.moveaxis(tr[:, elec, np.newaxis], 0, 1) for tr in ext_data]
            cnd_file["extChan"][elec]["data"] += elec_wise_data
        if run:
            cnd_file["runs"] += [run]*len(data)
        if session:
            cnd_file["sessions"] += [session]*len(data)
        if suffix:
            cnd_file["suffixes"] += [suffix]*len(data)
    return cnd_file


def create_stims(curr_stims_file, data, run, session, suffix, fs_data, fs_stim, annotations, feats, stim_data, stim_channels):
    # all stims saved to same feature set
    # For this specific dataset, create word/phoneme onset stim file
    if np.any(stim_data):
        # Untested path
        stim_file = {"names": [" + ".join([ch["ch_name"] for ch in stim_channels])], "fs": fs_stim, "data": stim_data,
                    "stimIdxs": np.array(range(0, len(stim_data)))+1, "condIdxs": np.array([1]*len(stim_data)),
                    "condNames": ['cond 1']}
    else:
        # Tested path
        descriptions_unpacked = [
            {**json.loads(obj["description"].replace('\'', '\"')),
             **{field: obj[field] for field in obj.keys() if field != 'description'}}
            for obj in annotations
        ]

        stim_file = None
        stim_data = [np.zeros((datum.shape[0], len(feats))) for datum in data]
        if not curr_stims_file:
            for i, feat in enumerate(feats):
                events = [d for d in descriptions_unpacked if d["kind"] in feat]
                curr_start = 0
                for j in range(0, len(stim_data)):
                    curr_end = curr_start + round(data[j].shape[0]*fs_stim/fs_data)  # if 1 set of annotations but multiple trials, add stim event to right trial
                    stim_data[j][[round(event["onset"]*fs_stim) for event in events if
                                   curr_start < round(event["onset"] * fs_stim) < curr_end], i] = 1
                    curr_start = curr_end
            stim_file = {"names": [" + ".join(feats)], "fs": fs_stim, "data": stim_data,
                        "stimIdxs": np.array(range(0, len(stim_data)))+1, "condIdxs": np.array([1]*len(stim_data)),
                        "condNames": ['cond 1']}
            if run:
                stim_file["runs"] = [run]*len(stim_file["data"])
            if session:
                stim_file["sessions"] = [session]*len(stim_file["data"])
            if suffix:
                stim_file["suffixes"] = [suffix]*len(stim_file["data"])
        else:
            for i, feat in enumerate(feats):
                stim_file = curr_stims_file
                events = [d for d in descriptions_unpacked if d["kind"] in feat]
                curr_start = 0
                for j in range(0, len(stim_data)):
                    curr_end = curr_start + round(data[j].shape[0]*fs_stim/fs_data) # if 1 set of annotations but multiple trials, add stim event to right trial
                    stim_data[j][[round(event["onset"]*fs_stim) for event in events if
                                  curr_start < round(event["onset"] * fs_stim) < curr_end], i] = 1
                    curr_start = curr_end
            stim_file["data"] += stim_data
            if run:
                stim_file["runs"] += [run]*len(data)
            if session:
                stim_file["sessions"] += [session]*len(data)
            if suffix:
                stim_file["suffixes"] += [suffix]*len(data)
            stim_file["stimIdxs"] = np.array(list(range(0, len(stim_file["data"]))))+1
            stim_file["condIdxs"] = np.array([1]*len(stim_file["data"]))
    return stim_file


def main(args):
    print("File path:", args.input_dir)
    print("Output directory:", args.output_dir)
    out_d = args.output_dir
    in_d = args.input_dir
    split_trials = False  # whether to break data into trials based on events
    stim_features = ["word", "phoneme"]  # dataset specific
    placeholder = [None]

    setup_dirs(out_d)

    datatype = mne_bids.get_datatypes(in_d)
    runs = mne_bids.get_entity_vals(in_d, "run")
    runs = runs if runs else placeholder
    subjects = mne_bids.get_entity_vals(in_d, "subject")
    subjects = subjects if subjects else placeholder
    tasks = mne_bids.get_entity_vals(in_d, "task")
    tasks = tasks if tasks else placeholder
    sessions = mne_bids.get_entity_vals(in_d, "session")
    sessions = sessions if sessions else placeholder
    suffixes = mne_bids.get_entity_vals(in_d, "suffix")
    suffixes = suffixes if suffixes else placeholder
    if not datatype:
        datatype = "eeg"  # default
    if isinstance(datatype, list) and not len(datatype) < 1:
        datatype = datatype[0]  # use only 1
    sub_counter = 0
    subs_tracker = {}
    for subject in subjects:
        a_cnd = None
        a_stim = None
        sub_counter += 1
        for session in sessions:
            subs_tracker[sub_counter] = subject
            for task in tasks:
                for run in runs:
                    for suffix in suffixes:
                        print(datetime.datetime.now())
                        try:
                            raw_data = mne_bids.read_raw_bids(mne_bids.BIDSPath(subject, session, task, run,
                                                                                root=in_d, suffix=suffix))
                            if split_trials:
                                data = naplib.io._crop_raw_bids(raw_data, None, None)
                            else:
                                data = [raw_data.get_data()]
                            data = [datum.transpose() for datum in data]

                            annotations = raw_data.annotations
                            fs = raw_data.info["sfreq"]
                            stim_idxs = ["stim" in ch_type for ch_type in raw_data.get_channel_types()]
                            stim_channels = np.array(raw_data.info["chs"])[stim_idxs]
                            ref_idxs = ["ref" in ch_type for ch_type in raw_data.get_channel_types()]
                            misc_idxs = ["misc" in ch_type for ch_type in raw_data.get_channel_types()]
                            ext_idxs = np.array(ref_idxs) + np.array(misc_idxs)
                            ext_channels = np.array(raw_data.info["chs"])[ext_idxs]
                            ext_data = [datum[:, ext_idxs] for datum in data]
                            data_idxs = np.logical_not(np.array(stim_idxs) + ext_idxs)
                            data_channels = np.array(raw_data.info["chs"])[data_idxs]
                            stim_data = [datum[:, stim_idxs] for datum in data]
                            data = [datum[:, data_idxs] for datum in data]

                        except FileNotFoundError:
                            continue
                        else:
                            a_cnd = transform_to_cnd(a_cnd, data, datatype, run, session, suffix, data_channels,
                                                     fs, ext_data, ext_channels)
                            a_stim = create_stims(a_stim, data, run, session, suffix, fs, fs,
                                                  annotations, stim_features, stim_data, stim_channels)
        try:
            hdf5storage.write(a_cnd, "neural", out_d + "/dataCND/dataSub" + subject + ".mat", matlab_compatible=True)
            if a_stim:
                hdf5storage.write(a_stim, "stim", out_d + "/dataCND/dataStim" + subject + ".mat",
                                  matlab_compatible=True)
        except Exception as e:
            print(e)
        else:
            print(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process some files.")

    # Add command-line arguments
    parser.add_argument('--input_dir', type=str, default='default_file.txt', help='Path to the input dataset', required=True)
    parser.add_argument('--output_dir', type=str, default='DataSetCND', help='Path to the output directory')

    # Parse the command-line arguments
    args = parser.parse_args()

    # Call the main function with the parsed arguments
    main(args)
    exit(0)
