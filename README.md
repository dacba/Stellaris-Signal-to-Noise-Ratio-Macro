Fiji/ImageJ Stellaris StN Ratio Macro
=============

#This README is out of date and no longer applies to the current version

This repository contains the SNR.ijm macro for Fiji/ImageJ
This macro calculates the signal to noise ratio of a Stellaris RNA FISH Experiment given the raw .nd2 files.

## How it works:
The user is queried for the Bounding tolerance, upward tolerance, and Z-score range, as well as the Polygon spot creation checkbox.
Files are opened by the macro for processing.  If the image is a Z stack and needs to be compressed, it is MaxIP merged.  The local maxima is found using the find maxima command and the derivative function.  The x and y values are fed, pair-by-pair into the dots or crazypoly function depending on the user input.
The crazypoly/dots function draws polygons or ellipsies (respectively) to the signal mask image. After all x and y values have been analyzed the signal mask is created and stored in the ROI manager, along with its inverse.  The signal, noise and background functions are called to measure and calculate the areas selected.
The results function is called and the images are stacked and saved as an 8-bit tif file.

## Input:

### User input

#### Bounding Tolerance
- Default = 0.1
- Determines the stringency of the bounding functions, lower meaning more strict
- Means the brightness has to drop to 90% of the center, then the change in brightness has to be below 10%

#### Upward Tolerance
- Default = 0.8
- Determines the stringency of the bounding function for upwards movement
- Means the brightness can rise 0.8 as much and still continue, allows for more lenient upward movement
- Best if dots are close together

#### Z-Score
- Default = -0.5
- Determines the maxima value
- Means the derivative function will output a value 0.5 standard deviation points below the median, instead of the median
- 0 means it will output the median, 1.0 will output one standard deviation point above the median, etc...

#### Polygon checkbox
- Default = Unchecked
- Determines if the polygon function or ellipse function will be used
- Ellipse function is very quick
- Polygon function takes much longer (~3x)

### Files
- Unprocessed Z Stacks in a file system, .nd2 files from a Nikon Ti Florescent Microscope


## Output:

### Output folder - "Out-SNRatio"
- Recreation of the target file system directory
- Within the folders contain the Merged images from analysis
- The results .csv file containing the information from the analysis
- The analysis pictures are 8-bit tif files containing 5 images...
	- the raw image (auto contrast)
	- First derivative of the raw image
	- Signal Mask, in black
	- Cell Noise, in white
	- Local Maxima Points


## Functions:

### process(dir, sub)
- Main recursive function
- Calls all other functions and handles file and window manipulation
- Saves images

### background()
- Measures background, the darkest part of the image
- Uses setAutoThreshold("Default")
	- More information on the Default algorithm can be found on the ImageJ website
	- Default was chosen due to its optimal selection of background pixels
- Creates a histogram of the background pixels selected

### noise()
- Measures the cell noise of the image
- Uses the roi manager to select the inverse of the dots and default dark selection
- Creates histogram of the pixels selected

### signal()
- Measures the signal from the signal mask

### dots(xi, yi)
- Searches N, S, E, and W from the given XY coordinates until the change in brightness is less than the tolerance (0.1 default)
- Calculates the change in brightness as relative to the central pixel(the brightest)
- Split into two steps
	- First step progresses until the brightness drops to 90% of the brightest pixel
	- Second step progresses until the change in brightness is less 10% of the brightest pixel
- Draws an ellipse around the signal dot

### crazypoly(xi, yi)
- Same as dots except it searches in the NE, SE, SW, and NW directions, and draws a polygon

### derivative()
- Creates the first derivative image of the raw image
	- Derivative image only measures positive change
	- MaxEntropy dark Threshold is used to select the brightest spots
	- Measure is used to find the maxima
	- The median value minus 0.5 of the standard deviation is returned

### results()
- Calculates the signal to noise ratio and transfers the results to a storage table
