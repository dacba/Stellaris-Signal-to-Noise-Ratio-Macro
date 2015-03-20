Fiji/ImageJ Stellaris StN Ratio Macro
=============

This repository contains the SNR.ijm macro for Fiji/ImageJ
This macro calculates the signal to noise ratio of a Stellaris RNA FISH Experiment given the raw .nd2 files.

Purpose
-------
The overall goal of this macro is to quickly and accurately separate a Stellaris RNA FISH image into three sections: Signal, Intra-cellular Noise, and Extra-cellular Noise.

Scope
-----
This program is designed as a quick and automatic measurement of Stellaris RNA FISH results.  It takes a look at the median signal value and the median noise values for it's calculations.  It is not intended for spot-by-spot analysis, spot count(only gives approximate count), cell-by-cell analysis, or co-localization analysis.

How it works
------------
The user is queried for the Bounding Stringency, Upward Stringency, Starting Maxima, and Maxima Tolerance.

Files are opened by the macro for processing.  If the image is a Z stack and needs to be compressed, it is MaxIP merged and Median merged.  The local maxima is found using the find maxima command.  The x and y values are fed, pair-by-pair into the dots or polygon function for masking.
The polygon/dots function draws polygons or ellipsies to the signal mask image. After all x and y values have been analysed the signal mask is created and stored in the ROI manager, along with its inverse.  The signal, noise and background are to measured for noise and background.

The results function calculates the relative Signal brightness, Noise Brightness and Signal to Noise Ratio. After, a tif with three pages, containing the MaxIP image, selections, and median image is created for troubleshooting and verification purposes.

Input
-----
### Sliders

##### Bounding Stringency
- Default = 0.25
- Determines the stringency of the bounding functions, higher meaning more strict

##### Upward Stringency
- Default = 0.8
- Determines the stringency of the bounding function for upwards movement

##### Starting Maxima
- Default = 20
- Determines where the program starts looking for the right Noise value to plug into the find maxima tool

##### Maxima Tolerance
- Default = 5
- Determines the target value for the second derivative of the maxima graph



#### Checkboxes
All default to off
##### Sum Intensity and Peak Intensity
* Estimates the sum intensity of the spots, or reports the peak intensity
* Saved as a csv file in the output folder
##### Plot Maxima Results
* Saves plots of spot counts vs noise values
* Useful for debugging
##### User Defined Area
* When enabled, the user is queried to exclude a selection from each image (or only analyze their selection)
* The program will ignore the users selection for measurements
* Useful if there are autoflourescent spots or if you would like to analyze a single cell
##### Signal Filtering
* Spots are filtered by their mean brightness
* Mean brightness is gathered and the standard deviation is estimated using Median Absolute Deviation
* Spots lower than 2 standard deviation points are filtered out
* Spots higher than 5 standard deviation points are analyzed separately
##### Advanced Options
* When enabled, a second dialog will appear containing advanced options and tweaks
* It's highly recommended to not change these options
* Some useful ones...
	* Exclude Files and Folders
		* Will exclude files and folders containing the string you enter here
	* Output Folder Name
		* Changes the name of the output folder
	* Include Large Spots
		* If the program is selecting large areas for the signal when it shouldn't, try disabling this option
	* Disable Warning codes
		* If you would rather not get any warning codes in the output csv file, enable this option
	* Warning cutoffs
		* Change these cutoffs to trigger warning codes more or less often 


### Folder Selection
- The use is queried for the location of the files.
- Only non-DAPI channel nd2 files will be processed


Output:
-------
#### Output folder - "Out-SNRatio"
 1. Contains the merged images from analysis
	* Useful for troubleshooting issues with signal or noise selections
 	* Merged Images are prefixed with their folder path from the root folder
 2. Root folder contains the result .csv files
 3. Root folder contains the extra files and folders if certain options are selected, such as "Plot Maxima Results"
	* See above for more options