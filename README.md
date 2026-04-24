# GIAnT-MATLAB
Glutamate Imaging Analysis Toolbox, MATLAB implementation


<img width="300" height="611.25" alt="GIAnT_schematic" src="GIAnT_schematic.png" />

## Epoch and Analysis Trial
For each experiment we run through the pipeline, we break down the data into epochs and analysis trials.

Epochs are full experimental sessions that can be aligned with each other (i.e. the same field of view and regions of interest are being imaged). Analysis trials are generally contiguous subsets (in time) of an epoch. These analysis trials may not align exactly with experimental trials.

For SLAP2, analysis trials are the experimental trials if the data was collected using the multi-trial functions of the SLAP2 and each trial is saved off the microscope in a different file. If data was continuously collected on SLAP2, the experiment will be split up into analysis trials of length 200000 lines (~20 sec) to help parallelize processing.

For data not collected on SLAP2, the current GIAnT pipeline sets Epochs to be 1 and each file that is selected to be processed is an analysis trial. These analysis trials must be able to be aligned to one another.

## Trial Table
Each experiment processed with GIAnT first gets a trial_table.h5 file that summarizes relevant file locations and analysis trial structures. The `slap2_info` group is only populated for SLAP2 experiments. The `motion_correction` and `source_extraction` groups are populated by downstream pipeline stages and will only be present once those stages have run. The structure of the trial_table is as below

```
📦 trial_table.h5
 ├ 📄 datadr
 ├ 📄 savedr
 ├ 📄 filename
 ├ 📄 true_trial_ix
 ├ 📄 epoch
 ├ 📦 slap2
 |  ├ 📦 ref_stack
 |  |  └ 📦 DMD{1,2}
 |  |     ├ IM
 |  |     ├ channels
 |  |     ├ Zs
 |  |     └ dmdPixel2SampleTransform
 |  ├ 📄 first_line
 |  ├ 📄 last_line
 |  ├ 📄 trial_start_time_inferred
 |  └ 📄 trial_end_time_from_pc
 ├ 📦 motion_correction
 |  ├ 📄 fn_reg_ds
 |  ├ 📄 fn_adata
 |  ├ 📄 fn_raw
 |  ├ 📄 registration_failed
 |  ├ 📄 first_line_original
 |  └ 📦 align_params
 └ 📦 source_extraction
    └ 📄 fn_raw
```

## Alignment Data
The motion correction scripts save out a H5 file ending in `_ALIGNMENTDATA.h5` that contains the alignment data for each trial. The structure of the alignment data is as below

```
📦 <trial_stem>_ALIGNMENTDATA.h5
 ├ 📄 numChannels
 ├ 📄 frametime
 ├ 📄 alignHz
 ├ 📄 motionDSc
 ├ 📄 motionDSr
 ├ 📄 recNegErr
 ├ 📄 motionC
 ├ 📄 motionR
 ├ 📄 DSframes
 ├ 📄 registrationFailed
 └ 📦 slap2
    ├ 📄 varFacDS
    ├ 📄 aError
    ├ 📄 Z
    ├ 📄 cropRow
    ├ 📄 cropCol
    ├ 📄 viewC
    ├ 📄 viewR
    ├ 📄 trimRows
    ├ 📄 trimCols
    ├ 📄 onlineMotionXshift
    ├ 📄 onlineMotionYshift
    └ 📄 onlineMotionZshift
```

## File Field Descriptions

### `trial_table.h5`

| Field | Size | Data type | Description |
| --- | --- | --- | --- |
| `datadr` | 1 x 1 | string | Data directory location |
| `savedr` | 1 x 1 | string | Results directory location |
| `filename` | nDMDs x total trials | string (ragged) | Relative file name from `datadr` |
| `true_trial_ix` | nDMDs x total trials | integer | Trial indices unraveled by epochs |
| `epoch` | nDMDs x total trials | integer | Epoch numbers |
| `slap2_info` | — | group | Only saved for SLAP2 experiments |
| `slap2_info/ref_stack/DMD{1,2}/IM` | image dims | numeric | Reference stack image |
| `slap2_info/ref_stack/DMD{1,2}/channels` | 1 x nChannels | numeric | Color channels |
| `slap2_info/ref_stack/DMD{1,2}/Zs` | 1 x nZ | numeric | Z positions |
| `slap2_info/ref_stack/DMD{1,2}/dmdPixel2SampleTransform` | 3 x 3 | numeric | Transformation matrix |
| `slap2_info/first_line` | nDMDs x total trials | integer | First line of each trial |
| `slap2_info/last_line` | nDMDs x total trials | integer | Last line of each trial |
| `slap2_info/trial_start_time_inferred` | 1 x total trials | integer | Inferred trial start times |
| `slap2_info/trial_end_time_from_pc` | 1 x total trials | integer | Trial end times from PC |
| `motion_correction` | — | group | Written by motion correction stage |
| `motion_correction/fn_reg_ds` | nDMDs x total trials | string | Registered + downsampled tif filename |
| `motion_correction/fn_adata` | nDMDs x total trials | string | Alignment metadata `_ALIGNMENTDATA.h5` filename |
| `motion_correction/fn_raw` | nDMDs x total trials | string | Registered raw-resolution file (Bergamo only) |
| `motion_correction/registration_failed` | nDMDs x total trials | bool | Whether registration failed |
| `motion_correction/first_line_original` | nDMDs x total trials | integer | Original `slap2_info/first_line` before reVolt adjustment |
| `motion_correction/align_params` | — | struct | Alignment parameters used |
| `source_extraction` | — | group | Written by source extraction stage |
| `source_extraction/fn_raw` | nDMDs x total trials | string | Raw file source extraction reads from per trial |

### `<trial_stem>_ALIGNMENTDATA.h5`

Top-level fields are shared across microscopes; `motionC`/`motionR`/`registrationFailed` are written by `StripRegistration.m` (Bergamo) and `DSframes`/`registrationFailed` by `MultiRoiRegistration.m` (SLAP2). The `slap2` group is only populated for SLAP2 experiments.

| Field | Size | Data type | Description |
| --- | --- | --- | --- |
| `numChannels` | 1 x 1 | integer | Number of channels in the recording |
| `frametime` | 1 x 1 | numeric | Seconds per downsampled frame |
| `alignHz` | 1 x 1 | numeric | Frame rate (Hz) at which alignment was performed |
| `motionDSc` | 1 x nDSframes | numeric | Inferred column shift per downsampled frame |
| `motionDSr` | 1 x nDSframes | numeric | Inferred row shift per downsampled frame |
| `recNegErr` | 1 x nDSframes | numeric | Per-frame reconstruction error used for motion censoring |
| `motionC` | 1 x nFrames | numeric | Column shift upsampled to raw frame rate (Bergamo only) |
| `motionR` | 1 x nFrames | numeric | Row shift upsampled to raw frame rate (Bergamo only) |
| `DSframes` | 1 x nDSframes | integer | Line indices of each downsampled frame (SLAP2 only) |
| `registrationFailed` | 1 x 1 | bool | Whether registration failed for this trial (SLAP2 only) |
| `slap2` | — | group | Only saved for SLAP2 experiments |
| `slap2/varFacDS` | rows x cols x nDSframes | numeric | Variance factor; multiply pixel intensity to get a value proportional to its variance |
| `slap2/aError` | 1 x nDSframes | numeric | Alignment error (1 − corrCoeff²) per downsampled frame |
| `slap2/Z` | 1 x 1 | numeric | Imaged Z position from microscope metadata |
| `slap2/cropRow` | 1 x 1 | integer | Row offset to add to ROIs to index into original recording |
| `slap2/cropCol` | 1 x 1 | integer | Column offset to add to ROIs to index into original recording |
| `slap2/viewC` | (rows+2·maxshift) x (cols+2·maxshift) | numeric | Column interpolation grid for remapping into saved tiff space |
| `slap2/viewR` | (rows+2·maxshift) x (cols+2·maxshift) | numeric | Row interpolation grid for remapping into saved tiff space |
| `slap2/trimRows` | 1 x nTrimRows | integer | Row indices used to remap images from the datafile into saved tiff space |
| `slap2/trimCols` | 1 x nTrimCols | integer | Column indices used to remap images from the datafile into saved tiff space |
| `slap2/onlineMotionXshift` | 1 x nDSframes | numeric | Online motion-correction X shift from the microscope |
| `slap2/onlineMotionYshift` | 1 x nDSframes | numeric | Online motion-correction Y shift from the microscope |
| `slap2/onlineMotionZshift` | 1 x nDSframes | numeric | Online motion-correction Z shift from the microscope |