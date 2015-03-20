#Signal to Noise Ratio Macro Changelog

#### Latest Version: <u>0.4.4</u>

## Version 0.1
##### January 30, 2015
* First release for in-house use

### Version 0.1.1
##### February 3, 2015
* Added Coefficient of Variation measurement
* Optimized Plot Maxima Graph
* Tweaked maxima search function
  * Measures absolute value of second derivative
  * Inverted and removed /10 for tolerance_maxima condition
* Added Advanced Options
  * Output Folder Name Textbox
  * Objective Magnification Choice(Placeholder)
  * Tolerance Drop Slider
  * Count Bad Spots Checkbox
  * Disable Warning Codes
  * Warning Cutoffs
    * Coefficient of Variation
    * Spot Count
    * Bad Spot Count

## Version 0.2
##### February 4, 2015
* Uses Max Intensity Merge for Signal, uses Median Intensity Merge for Intra and Extra Cellular Noise
* Debug Image has new third slice
  * Median Intensity Merge image, slightly blurred
  * Not Normalized to MaxIP image

### Version 0.2.1
##### February 6, 2015
* Minor bug fixes
* Commented more Code
* Added and "Exclude" Advanced Option
	* Will allow the user to exclude files or folders containing a specific phrase
* Debug images and results files will be saved in a folder named after the inputted settings
	* "Bounding Stringency"-"Upward Stringency"-"Maxima Tolerance"
	* e.g. "0.25-0.8-4"
* File system will no longer be recreated
* Output .csv files will have the current version number in their header

## Version 0.3
##### February 12, 2015
* Added Experimental Option to run a statistical analysis on spots
* Cuts off bottom 0.5 IQR and separates the top 0.5 IQR
	* Top IQR is deemed bright data points, and a separate SNR analysis is done
* Shortened table headers
* Updated SNR_Signal, SNR_Noise and SNR_polygon to be compatible with spot by spot or regular analysis
* Added SNR_bright_results to deal with the bright analysis

### Version 0.3.1
##### February 13, 2015
* Switch to MADe instead of IQR
* Renamed Variables for consistency
* Fixed issue when no bright spots were found
	* Added null results function

### Version 0.3.2
##### February 13, 2015
* Added User defined selection
	* User is prompted to draw a selection, and spot analysis is done only on that selection
	* Selecting nothing will analyze the entire image

### Version 0.3.3
##### February 17, 2015
* Added exclusion mode to User Defined Selection
* Selection can now be set to exclude the user defined selection, instead of only analyzing the selection
* Fixed conflict with Filter Spots and User Defined Selection
	* Also fixed a crash when no bright spots were detected and these two options were selected
* Fixed an extra blank slice being added to the final merged image when no bright spots were detected
* Fixed a crash when User Defined Area was not selected
* Fixed a bug where the merged images were reversed
* Changed Folder naming to be more descriptive
	* Created a unique hex code when user defined selection is selected
* Final output folder naming is now more flexible (code change)
* Fixed an issue where no noise would be selected in user defined area mode
	* Noise and Background were being thresholded based on the entire image, not the selection
	* Noise and Background are now measured and thresholded based on the selection made, not the entire image


### Version 0.3.4
##### February 23, 2015
* Updated Ellipse bounding
	* Now on par with polygon
	* Returns the size, and will draw to the window you choose
	* Removed Ellipse bounding warning
* Program will use ellipse when there are >5000 spots in order to save time
	* User will be notified if ellipse bounding will be used
	* "Force Polygon" option (previously "Polygon bounding") will always use the polygon function
* Fixed bug where raw and condensed results would be offset when no bright spots were found while running the filter spots option
* Fixed issue with sum intensity and peak intensity having an empty item at the end of the list

## Version 0.4
##### February 24, 2015
* Table headers updated to be more flexible
* Noise and background no long exclude singal mask
* Maxima search now looks at an 11 wide window, weighted moving average
* Plot Maxima results plots log transformed data
* Warning codes are disabled by default
* Maxima tolerance default now 5 due to changes
* Fixed bug where find_maxima would be run on median intensity image when plot maxima results was selected
* Fixed bug when the debug images would be reversed when user defined area was selected

### Version 0.4.1
##### March 5, 2015
* Added 1.5D gaussian fit function that fits x and y cross sections to gaussian and creates mask like ellipse and polygon
* Added close all to beginning of macro
* Removed old debugging code
* Revamped Signal expansion code
	* User is queried of their selection
		* Normal operation
			* Ellipse is used when spot count >3000
		* Force Polygon
			* Always use polygon function
		* Gaussian
			* Use gaussian function
* Results tables note expansion algorithm
* sqrt(2) sigfig increased to 10

### Version 0.4.2
##### March 13, 2015
* Tested and Verified on ImageJ version 1.48v
* Reverted plot maxima reporting log transformed data
* Added linear fit maxima search option
	* Locates straight line segments after running regular maxima search function
	* Fits data points until r^2 value drops below 0.95
* Added Score ouput
	* Images are scored based on SNR and Signal
	* Score = SNR * Signal / 100
* Spots that have been filtered out are added to bad_spot count
* bad_spot count renamed to filtered spot

### Version 0.4.3
##### March 18, 2015
* Cleaned up code
* Improved Dialog
* Changed score to use diff between signal and noise
	* Score = SNR * (Signal - Noise) / 100
* Increased ellipse trigger to >5000 spots from >3000 spots
* Fixed bug where linear fit would insert plots in output images
* Linear fit moved to advanced options and set to disabled by default
* Added more information in the macro header

### Version 0.4.4
##### March 19, 2015
* Macro now reports an estimate on time remaining
	* Reports estimated time down to the minute
	* Two new functions created: SNR_natural_time and SNR_timediff
* SNR_natural_time converts an array containing (days, hours, minutes) to natural text, and accepts a prefix
* SNR_timediff returns the difference between two times(ms) as an array of (days, hours, minutes)
* Added Network delay option (default: 0s)
	* Will delay analysis between images to prevent network saturation