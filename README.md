Fiji/ImageJ Stellaris StN Ratio Macro
=============

This repository contains the SNR.ijm macro for Fiji/ImageJ.

This macro calculates the signal to noise ratio of a Stellaris RNA FISH Experiment given the image stacks.

Purpose
-------
The overall goal of this macro is to quickly and accurately separate a Stellaris RNA FISH image into three sections: Signal, Intra-cellular Noise, and Extra-cellular Background.  Then, to calculate the ratio of signal to Intra-cellular Noise relative to the Extra-cellular Background.

Scope
-----
This program is designed as a quick and automatic measurement of Stellaris RNA FISH results.  It is not intended for spot-by-spot analysis, spot count, cell-by-cell analysis, or co-localization analysis.

How it works
------------
Files are opened by the macro for processing.  The image stacks are compressed using Max and Median intensity projection methods.  The local maxima for the signal is found.  Using the local maxima locations, a mask is created that selects all signal.  Local thresholding selects Intra-cellular Noise.

The results calculated are the relative Signal brightness, Noise Brightness and Signal to Noise Ratio. After, a three page tiff file is created of the max intensity merge image, selections, and median intensity merge image for troubleshooting and verification purposes.

Running the Macro
-----
###Installation
#####Single Use
* Plugins > Macros > Install..
	* Select the macro file ending in ".ijm"

#####Startup
* Navigate to C:\Fiji.app\macros
* Copy and paste the macro text to the StartupMacros.fiji.ijm file

###Execute
* Click the macro in Plugins > Macros > Calculate Signal to Noise Ratio vx.x.x...[c] or press the "c" key
* You should now see a window called "Spot Processor"
	* Change the settings on this window to change the behavior of the macro, see below for more details
* Press "OK"
* Select the folder you wish to analyze
* Press "Select"
* Wait for the program to finish it's analysis
	* Check the log window for the estimated time remaining
	* If the macro freezes or gives you an error

Input
-----

###Masking Options
#####Signal Masking Option
* Determines the algorithm used to mask signal
* Default is "Normal" or 8 point polygon
#####Noise Masking Option
* Determines the algorithm used to mask noise
* Default is "Normal"
* Other option is none
	* Selecting "None" will compare signal to the average of the entire image (excluding the signal)
#####Background Masking Option
* Determines the algorithm used to mask background
* Default is "Normal"
* Other options:
	* Histogram Peak
		* Selects all pixels below the peak in the histogram
	* Gaussian Histogram Peak
		* Fits a gaussian curve to the histogram and selects all pixels below that value
	* Bottom 10%
		* Selects the bottom 10% of pixels

###Other Options

##### Sum Intensity and Peak Intensity
* Estimates the sum intensity of the spots, or peak intensity
* Saved as a csv file in the output folder
##### Plot Maxima Results
* Saves plots of spot counts vs noise values
* Useful for debugging
##### User Defined Area
* When enabled, the user is asked to either exclude their selection from analysis or only analyze their selection
* Useful if there are autoflourescent spots or if you would like to analyze a single cell
##### Signal Filtering
* Spots are filtered out in two stages
	* Spots close to the noise value are filtered out
	* Spots significantly lower than the mean are filtered out
* Spots significantly higher than the mean are analyzed separately
	* Usually separates transcription bursts or autofluorescent spots
#####Custom LUT
* Allows the user to define custom LUT values for the final outputted images

##### Auto Trim Z-stack
* Enables trimming of images in the z-stack without any signal

##### Re-analyze images
* Analyzes images even if they have been analyzed before

##### Mark Unmeasured Areas
* If enabled, all areas not counted towards either noise, signal, or background will be marked with diagonal hashes

##### Advanced Options
* When enabled, a second dialog will appear containing advanced options and tweaks
* It's highly recommended to not change these options
* Some useful options...
	* Exclude Files and Folders
		* Will exclude files and folders containing the string you enter here
	* Output Folder Name
		* Changes the name of the output folder
	* Disable Warning codes
		* If you would rather not get any warning codes in the output csv file, enable this option

* Bounding Stringency
	* Default = 0.2
	* Determines the stringency of the signal bounding functions, higher meaning more strict

* Upward Stringency
	- Default = 0.8
	- Determines the stringency of the signal bounding function for upwards movement

* Maxima Tolerance
	- Default = 8
	- Determines the number of spots to analyze

### Output folder - "Out-SNRatio"
 1. Contains the merged images from analysis
	* Useful for troubleshooting issues with signal or noise selections
 	* Merged Images are prefixed with their folder path from the root folder
 2. The root folder contains the result .csv files
	*  Raw results are stored in raw_results.csv
		*  Contains the raw measurements of each selection
	*  Condensed results are stored in condensed_results.csv
		*  Contains the calculated and condensed measurements of each file 
 3. The root folder contains the extra files and folders if certain options are selected, such as "Plot Maxima Results"

##Troubleshooting

###Warnings
1. Potentially Incompatible Operating System
	* This macro was developed on Windows 7 for Windows 7 and has not been tested on other versions of ImageJ/Fiji, proceed with caution
2. Incompatible ImageJ Version
	* ImageJ version 1.49n is known to not work properly with this macro
	* Results may not save correctly if using other versions
3. Tolerances outside of recommended ranges
	* One or more of your input settings were outside of the recommended ranges
	* Refer to the recommended ranges in the window for help

###FAQ
1. The program won't read my raw image files, what file types does it accept?
	* This macro expects raw z-stack images from a non-confocal microscope
	* This macro will accept 16 bit, multi page, tiff files and raw nd2 files from nikon microscopes
	* If your raw files are not nd2 files, convert them to 16 bit tiff files with multiple pages
	* This program will analyze single channel images only.  If your file type contains multiple channels, this program will not read it correctly
2. The spot count is wrong, how do I fix it?
	* Change the maxima tolerance to increase or decrease the number of spots selected
	* Alternatively, turn off signal filtering if the program is not selecting your signal
3. The spot count is still wrong, what do I do?
	* This program was designed for images with signal.  If your image does not contain signal molecules, or it is difficult to distinguish from the surrounding noise, this program will not be able to select it
4. The macro is selecting too much/too little area around the signal, how can I fix this?
	* Change the bounding stringency to reduce or expand the number of pixels the program will select
	* If the macro is still exibiting strange behaviour, change the upward stringency to 1.0
5. What does the "Score" mean?
	* Score is a numerical representation of the quality of an image
	* It is SNR * log10(signal - noise - 100)
		* Both the signal to noise ratio and the absolute difference between the signal and noise are important
		* An image of signal 5 and noise 1 will be worse than an image of signal 500 and noise 100
6. 