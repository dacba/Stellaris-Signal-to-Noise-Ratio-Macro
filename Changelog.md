#Signal to Noise Ratio Macro Changelog

Below is the changelog for in-house release versions

### Version 0.3.4
##### 2/23/15
* Updated Ellipse bounding
	* Now on par with polygon
	* Returns the size, and will draw to the window you choose
	* Removed Ellipse bounding warning
* Program will use ellipse when there are >5000 spots in order to save time
	* User will be notified if ellipse bounding will be used
	* "Force Polygon" option (previously "Polygon bounding") will always use the polygon function
* Fixed bug where raw and condensed results would be offset when no bright spots were found while running the filter spots option
* Fixed issue with sum intensity and peak intensity having an empty item at the end of the list

### Version 0.3.3
##### 2/17/15
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

### Version 0.3.2
##### 2/13/15
* Added User defined selection
	* User is prompted to draw a selection, and spot analysis is done only on that selection
	* Selecting nothing will analyze the entire image

### Version 0.3.1
##### 2/13/15
* Switch to MADe instead of IQR
* Renamed Variables for consistency
* Fixed issue when no bright spots were found
	* Added null results function

###Version 0.3
##### 2/12/15
* Added Experimental Option to run a statistical analysis on spots
* Cuts off bottom 0.5 IQR and separates the top 0.5 IQR
	* Top IQR is deemed bright data points, and a separate SNR analysis is done
* Shortened table headers
* Updated SNR_Signal, SNR_Noise and SNR_polygon to be compatible with spot by spot or regular analysis
* Added SNR_bright_results to deal with the bright analysis

### Version 0.2.1
##### 2/6/15
* Minor bug fixes
* Commented more Code
* Added and "Exclude" Advanced Option
	* Will allow the user to exclude files or folders containing a specific phrase
* Debug images and results files will be saved in a folder named after the inputted settings
	* "Bounding Stringency"-"Upward Stringency"-"Maxima Tolerance"
	* e.g. "0.25-0.8-4"
* File system will no longer be recreated
* Output .csv files will have the current version number in their header

### Version 0.2
##### 2/4/15
* Uses Max Intensity Merge for Signal, uses Median Intensity Merge for Intra and Extra Cellular Noise
* Debug Image has new third slice
  * Median Intensity Merge image, slightly blurred
  * Not Normalized to MaxIP image

### Version 0.1.1
##### 2/3/15
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

### Version 0.1
##### 1/30/15
* First release for in-house use
