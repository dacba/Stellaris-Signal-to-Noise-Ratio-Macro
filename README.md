Fiji/ImageJ Stellaris StN Ratio Macro
=============

This repository contains the SNR.ijm macro for Fiji/ImageJ
This macro calculates the signal to noise ratio of a Stellaris RNA FISH Experiment given the raw .nd2 files.

Purpose
-------
The overall goal of this macro is to quickly and accurately separate a Stellaris RNA FISH image into three sections: Signal, Intra-cellular Noise, and Extra-cellular Noise.

Scope
-----
This program is designed as a quick and automatic measurement of Stellaris RNA FISH results.  It takes a look at the median signal value and the median noise values for it's calculations.  It is not intended for spot-by-spot analysis, spot count(give approximate count), cell-by-cell analysis, or co-localization analysis.

How it works
------------
The user is queried for the Bounding Stringency, Upward Stringency, Starting Maxima, and Maxima Tolerance.
Files are opened by the macro for processing.  If the image is a Z stack and needs to be compressed, it is MaxIP merged and Median merged.  The local maxima is found using the find maxima command.  The x and y values are fed, pair-by-pair into the dots or polygon function for masking.
The polygon/dots function draws polygons or ellipsies to the signal mask image. After all x and y values have been analysed the signal mask is created and stored in the ROI manager, along with its inverse.  The signal, noise and background functions are called to measure the thresholded areas for noise and background.
The results function calculates the relative Signal brightness, Noise Brightness and Signal to Noise Ratio. After, a tif with three pages, containing the MaxIP image, selections, and median image is created for troubleshooting and verification purposes.

Input
-----
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
- Default = 4
- Determines the target value for the second derivative of the maxima graph


#### Folder
- The use is queried for the location of the files.
- Only non-DAPI channel nd2 files will be processed


Output:
-------
#### Output folder - "Out-SNRatio"

 1. Recreates the target file system directory
 2. Contains the merged images from analysis
 2. Root folder contains the results .csv files


Functions:
----------
#### SNR_main(dir, sub)
- Main recursive function
- Calls all other functions and handles file and window manipulation
- Saves images

#### SNR_background()
- Measures background, the darkest part of the image
- Uses setAutoThreshold("Default")
	- More information on the Default algorithm can be found on the ImageJ website
	- Default was chosen due to its optimal selection of background pixels

#### SNR_noise()
- Measures the cell noise of the image
- Uses the roi manager to select the inverse of the dots and the default dark threshold selection

#### SNR_signal()
- Measures the signal from the signal mask

#### SNR_dots(xi, yi)
Note: This function is dated and slated for removal
- Searches N, S, E, and W from the given XY coordinates until the change in brightness is less than the tolerance (0.1 default)
- Calculates the change in brightness as relative to the central pixel(the brightest)
- Split into two steps
	- First step progresses until the brightness drops to 90% of the brightest pixel
	- Second step progresses until the change in brightness is less 10% of the brightest pixel
- Draws an ellipse around the signal dot

#### SNR_polygon(xi, yi)
- Similar to dots
- Uses the average difference in change of brightness in a 3 pixel window

#### SNR_maximasearch()
- Searches for the right Noise value for the image
- Starts at the maxima start vairable and moves upward by 5
- Calculates the change in change of spot count (second derivative)
- Once the change in slope(second derivative) drops below the maxima tolerance, it stops searching

#### SNR_results()
- Calculates the signal to noise ratio, Relative Signal and Noise, Creates warning codes
- Saves these results to the Raw table then the Condensed Table
