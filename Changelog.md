#Signal to Noise Ratio Macro Changelog

Below is the changelog for the in-house release versions

### Version 0.2
#### 2/4/15
* Uses MaxIP for Signal, uses Median for Intra and Extra Cellular Noise
* Debug Image has new third slice
..* Median Intensity Merge image, slightly blurred
..* Not Normalized to MaxIP image

### Version 0.1.1
#### 2/3/15
* Added Coefficient of Variation measurement for 
* Optimized Plot Maxima Graph
* Tweaked maxima search function
..* Measures absolute value of second derivative
..* Inverted and removed /10 for tolerance_maxima condition
* Added Advanced Options
..* Output Folder Name Textbox
..* Objective Magnification Choice(Placeholder)
..* Tolerance Drop Slider
..* Count Bad Spots Checkbox
..* Disable Warning Codes
..* Warning Cutoffs
....* Coefficient of Variation
....* Spot Count
....* Bad Spot Count

### Version 0.1
#### 1/30/15
* First release for in-house use
