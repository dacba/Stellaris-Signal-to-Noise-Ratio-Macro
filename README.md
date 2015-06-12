Fiji/ImageJ Stellaris StN Ratio Macro
=============

This repository contains the SNR.ijm macro for Fiji/ImageJ.

This macro calculates the signal to noise ratio of a Stellaris RNA FISH Experiment given the image stacks.

Purpose
-------
The overall goal of this macro is to quickly and accurately separate a Stellaris RNA FISH image into three sections: Signal, Intra-cellular Noise, and Extra-cellular Background.  Then, to calculate the ratio of signal to Intra-cellular Noise relative to the Extra-cellular Background.

Scope
-----
This program is designed as a quick and automatic measurement of Stellaris RNA FISH results.  It is not intended for spot-by-spot analysis, spot count(only gives approximate count), cell-by-cell analysis, or co-localization analysis.

How it works
------------
The user is presented with tolerance and stringency options to tweak the behavior of the macro and then queried for the folder location of the images the user wishes to analyze.

Files are opened by the macro for processing.  The image stacks are compressed using Max and Median intensity projection methods.  The local maxima for the signal is found using the "Find Maxima" command.  Using the local maxima, a mask is created that selects all signal.  Local thresholding selects Intra-cellular Noise.

The results calculated are the relative Signal brightness, Noise Brightness and Signal to Noise Ratio. After, a tif with three pages, containing the MaxIP image, selections, and median image is created for troubleshooting and verification purposes.

Input
-----

###Bounding and Spot Count Alterations
##### Bounding Stringency
- Default = 0.2
- Determines the stringency of the bounding functions, higher meaning more strict

##### Upward Stringency
- Default = 0.5
- Determines the stringency of the bounding function for upwards movement

##### Maxima Tolerance
- Default = 5
- Determines the target value for the second derivative of the maxima graph

###Other Options

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
* Spots are filtered out if their peak brightness falls within three standard deviation points of the mean noise value
* Mean brightness is gathered and the standard deviation is estimated using Median Absolute Deviation
* Spots lower than 2 (default) standard deviation points are filtered out
* Spots higher than 5 (default) standard deviation points are analyzed separately
##### Advanced Options
* When enabled, a second dialog will appear containing advanced options and tweaks
* It's highly recommended to not change these options
* Some useful ones...
	* Exclude Files and Folders
		* Will exclude files and folders containing the string you enter here
	* Output Folder Name
		* Changes the name of the output folder
	* Disable Warning codes
		* If you would rather not get any warning codes in the output csv file, enable this option

Output:
-------
#### Output folder - "Out-SNRatio"
 1. Contains the merged images from analysis
	* Useful for troubleshooting issues with signal or noise selections
 	* Merged Images are prefixed with their folder path from the root folder
 2. Root folder contains the result .csv files
 3. Root folder contains the extra files and folders if certain options are selected, such as "Plot Maxima Results"
	* See above for more options