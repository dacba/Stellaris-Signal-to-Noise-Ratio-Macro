macro "Calculate Signal to Noise Ratio v0.3.3...[c]" {
version = "0.3.3";
/*
2015-2-17
Version 0.3.3 - for in-house use only, do not distribute

This macro opens a directory and does an analysis of spots
Based off of "TrevorsMeasure" or "Measure Dots..."
Uses Find Maxima to find spots and expand the points to a selection used for spot analysis
Use the Default threshold to determine cell noise and background values

In regards to Significant Figures
	All pixels are treated as exact numbers, thus no significant figures rules apply to them or results obtained from them.

Tested on ImageJ version 1.49o
!!!1.49n does not work as intended!!!
*/

//Initialize
setBatchMode(true);
setOption("ShowRowNumbers", false);
requires("1.49m");
run("Set Measurements...", "area mean standard min median redirect=None decimal=3");
run("Input/Output...", "jpeg=85 gif=-1 file=.csv save_column");
setFont("SansSerif", 22);
print("\\Clear");
run("Clear Results");



if (indexOf(getVersion(), "1.49n") > -1) {
	Dialog.create("Incompatible ImageJ Version");
	Dialog.addMessage("You are using ImageJ version 1.49n, which is incompatible with this macro.\n \nDowngrade to 1.49m or upgrade to 1.49o by going to \"Help\" > \"Update ImageJ\" and then\nselecting \"Previous\" at the bottom of the drop down menu, or \"1.49o\" to upgrade.");
	Dialog.addCheckbox("I want to do it anyway", false);
	Dialog.show();
	temp = Dialog.getCheckbox();
	if (temp == false) exit("Upgrade by going to \"Help\" > \"Update ImageJ\" and selecting \"Previous\"");
	}


//Default Variables
tolerance_bounding = 0.25; //Tolerance for ellipse bounding. Higher means smaller ellipsis 
tolerance_upward = 0.8; //Tolerates upward movement (0 means any upward movement will be tolerated, 1 means tolerance will be the same as downward movement)
maxima = 20;
poly = true;
tolerance_maxima = 4;
sum_intensity = false;
peak_intensity = false;
plot = false;
spotbyspot = false;
user_area = false;
user_area_rev = false;
//Advanced Options
advanced = false;
output = "Out-SNRatio";
objective = 60;
count_bad = true;
warning_cvspot = 0.5;
warning_cvnoise = 0.25;
warning_spot = 100;
warning_badspot = 20;
warning_disable = false;
exclude = "NULL";
low_user = 3;
high_user = 4;

//Dialog
Dialog.create("Spot Processor");

Dialog.addMessage("Please enter the Bounding Stringency, Upward Stringency and Maxima Tolerance");
Dialog.addSlider("Bounding Stringency(Higher = smaller spots):", 0.01, 0.5, tolerance_bounding);
Dialog.addSlider("Upward Stringency(Higher = smaller spots):", 0, 1, tolerance_upward);
Dialog.addSlider("Starting Maxima(Higher = faster):", 0, 200, maxima);
Dialog.addSlider("Maxima Tolerance(Higher = More Spots):", 1, 50, tolerance_maxima);
Dialog.addCheckboxGroup(3, 3, newArray("Polygon Bounding", "Sum Intensity", "Peak Intensity", "Plot Maxima Results", "Signal Filtering(Experimental)", "Advanced Options", "User Defined Area"), newArray(poly, sum_intensity, peak_intensity, plot, spotbyspot, advanced, user_area));
Dialog.show();

//Retrieve Choices
tolerance_bounding = Dialog.getNumber();
tolerance_upward = Dialog.getNumber();
maxima = Dialog.getNumber();
tolerance_maxima = Dialog.getNumber();
poly = Dialog.getCheckbox();
sum_intensity = Dialog.getCheckbox();
peak_intensity = Dialog.getCheckbox();
plot = Dialog.getCheckbox();
spotbyspot = Dialog.getCheckbox();
advanced = Dialog.getCheckbox();
user_area = Dialog.getCheckbox();
maxima_start = maxima;
tolerance_drop = (tolerance_bounding / 5) + 0.89;

if (poly == false) {
	Dialog.create("Warning");
	Dialog.addMessage("The Ellipse function is running an older algorithm for bounding.");
	Dialog.addMessage("If you wish to continue using the Ellipse function instead of the Polygon function, press \"Cancel\" and reduce the Bounding Stringency to 0.1 instead 0.25.");
	Dialog.show();
	}

//Warn if Choices are outside of recommended range
if (tolerance_bounding > 0.3 || tolerance_bounding < 0.2 || tolerance_upward < 0.5 || tolerance_maxima > 5 || tolerance_maxima < 2 || maxima > 50) {
	Dialog.create("Warning");
	Dialog.addMessage("One or more of your variables are outside of the recommended ranges.\nPlease refer to the recommended ranges below.");
	Dialog.addMessage("Bounding Stringency: 0.2 - 0.3  (" + tolerance_bounding + ")\nUpward Stringency: 0.5 - 1.0  (" + tolerance_upward + ")\nStarting Maxima: 0 - 50  (" + maxima + ")\nMaxima Stringency: 2 - 5  (" + tolerance_maxima + ")");
	Dialog.addMessage("If you would like to continue using these variables press \"OK\" to continue\nBe sure to check the merged tif files and warning codes in the results file to ensure the analysis was done correctly");
	Dialog.show();
	}

if (advanced == true) { //Advanced Options Dialog
	waitForUser("Some advanced options will break the macro\nOnly change settings if you know what you're doing\n\nSome settings have not been fully implemented yet and are placeholders at the moment");
	
	Dialog.create("Advanced Options");
	Dialog.addString("Output Folder Name:", output);
	Dialog.addString("Exclude Files and Folders:", exclude);
	Dialog.addChoice("Objective Magnification", newArray(60, 100));
	Dialog.addSlider("Tolerance Drop", 0.5, 1, tolerance_drop);
	Dialog.addSlider("MADe Bottom", 1, 5, low_user);
	Dialog.addSlider("MADe Top", 1, 5, high_user);
	Dialog.addCheckboxGroup(2, 2, newArray("Include Large Spots", "Disable Warning Codes"), newArray(count_bad, warning_disable));
	Dialog.addMessage("Warning Cutoffs");
	Dialog.addSlider("Coefficient of Variation S", 0, 2, warning_cvspot);
	Dialog.addSlider("Coefficient of Variation N", 0, 2, warning_cvnoise);
	Dialog.addSlider("Suspicious Spot Count", 0, 200, warning_spot);
	Dialog.addSlider("Bad Spot Count", 0, 50, warning_badspot);
	Dialog.show();
	
	output = Dialog.getString();
	exclude = Dialog.getString();
	objective = Dialog.getChoice();
	objective /= 60;
	objective = 1 / objective;
	tolerance_drop = Dialog.getNumber();
	low_user = Dialog.getNumber();
	high_user = Dialog.getNumber();
	count_bad = Dialog.getCheckbox();
	warning_disable = Dialog.getCheckbox();
	warning_cvspot = Dialog.getNumber();
	warning_cvnoise = Dialog.getNumber();
	warning_spot = Dialog.getNumber();
	warning_badspot = Dialog.getNumber();
	}

//Open Tables
run("Table...", "name=SNR width=400 height=200");
if (peak_intensity == true) run("Table...", "name=Peak width=400 height=200");
if (sum_intensity == true) run("Table...", "name=Sum width=400 height=200");
run("Table...", "name=Condense width=400 height=200");

//Initialize SNR table
if (poly == false ) print("[SNR]", "Version " + version + " Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Ellipse");
else print("[SNR]", "Version " + version + " Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Polygon");
print("[SNR]", "Area, Mean, StdDev, Min, Max, Median, File, Description, Coefficient of Variation, Mean SNR, Median SNR, Signal, Noise, Spots, Bad Spots, Maxima, Warning Code");

//Initialize Condensed Table
if (poly == false ) print("[Condense]", "Version " + version + " Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Ellipse");
else print("[Condense]", "Version " + version + " Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Polygon");
if (spotbyspot == true) print("[Condense]", "File, Mean SNR, Median SNR, Bright Median SNR, Signal, Bright Signal, Noise, Spots, Bad Spots, Maxima, Warning Code");
else print("[Condense]", "File, Mean SNR, Median SNR, Signal, Noise, Spots, Bad Spots, Maxima, Warning Code");

//Initialize Peak and Sum intensity tables if option was chosen
if (peak_intensity == true) print("[Peak]", "Peak Brightness");
if (sum_intensity == true) print("[Sum]", "Sum Intensity");

//Create Directories
output_name = "Results " + tolerance_bounding + "-" + tolerance_upward + "-" + tolerance_maxima;
if (spotbyspot == true) output_name += "-filtered-" + low_user + "-" + high_user;
if (user_area == true) output_name += "-selection-" + toHex(round(random*random*random*100000000));

dir = getDirectory("Choose Directory containing .nd2 files"); //Get directory
outDir = dir + output + "\\"; //Create base output directory
File.makeDirectory(outDir); //Create base output directory
outDir = outDir + output_name + "\\";//Create specific output directory
File.makeDirectory(outDir); //Create specific output directory
if (plot == true) File.makeDirectory(outDir + "\\Plots\\"); //Create Plots directory

//RUN IT!
SNR_main(dir, ""); 

//Save it!
if (indexOf(getVersion(), "1.49n") > -1) { //Save as Text if running 1.49n
	selectWindow("SNR");
	saveAs("Text", outDir + "Results_Raw.csv");
	run("Close");
	selectWindow("Condense");
	saveAs("Text", outDir + "Results_Condensed.csv");
	run("Close");
	if (peak_intensity == true) {
		selectWindow("Peak");
		saveAs("Text", outDir + "Results_PeakIntensity.csv");
		run("Close");
		}
	if (sum_intensity == true) {
		selectWindow("Sum");
		saveAs("Text", outDir + "Results_SumIntensity.csv");
		run("Close");
		}
	}
else { //Save as Measurement csv file if running other
	selectWindow("SNR");
	saveAs("Measurements", outDir + "Results_Raw.csv");
	run("Close");
	selectWindow("Condense");
	saveAs("Measurements", outDir + "Results_Condensed.csv");
	run("Close");
	if (peak_intensity == true) {
		selectWindow("Peak");
		saveAs("Measurements", outDir + "Results_PeakIntensity.csv");
		run("Close");
		}
	if (sum_intensity == true) {
		selectWindow("Sum");
		saveAs("Measurements", outDir + "Results_SumIntensity.csv");
		run("Close");
		}
	}


function SNR_main(dir, sub) {
	run("Bio-Formats Macro Extensions");
	list = getFileList(dir + sub);//get file list 
	n = 0;
	for (i=0;i<list.length; i++){ //for each file
		path = sub + list[i];
		if (endsWith(list[i], "/") && indexOf(path, output) == -1 && indexOf(path, exclude) == -1) {
			//File.makeDirectory(outDir + path); //Recreate file system in output folder
			SNR_main(dir, path); //Recursive Step
			}
		else if (endsWith(list[i], ".nd2") && indexOf(list[i], exclude) == -1) {
			strip = substring(list[i], 0, indexOf(list[i], ".nd2"));
			stripath = replace(substring(path, 0, indexOf(path, ".nd2")), "/", "_");
			run("Bio-Formats Importer", "open=[" + dir + path + "] autoscale color_mode=Grayscale view=Hyperstack");
			info = getImageInfo();
			if (indexOf(substring(info, indexOf(info, "Negate") - 6, indexOf(info, "Negate")), "DAPI") > -1 || nSlices == 1) close(); //Close if it's the DAPI channel or single slice
			else {
			//Initialize Image
			print("File: " + path);
			height = getHeight();
			width = getWidth();
			window_raw = getImageID();
			run("Z Project...", "projection=[Max Intensity]"); //Max intensity merge
			window_MaxIP = getImageID();
			selectImage(window_raw);
			run("Z Project...", "projection=Median"); //Max intensity merge
			window_Median = getImageID();
			run("Gaussian Blur...", "sigma=3");
			selectImage(window_raw);
			run("Close");
			
			if (user_area == true) {
				selectImage(window_MaxIP);
				run("Enhance Contrast", "saturated=0.01");
				setBatchMode('show');
				Dialog.create("User Defined Area Option");
				Dialog.addRadioButtonGroup("Would you like to Exclude your selection from the analysis or only analyze your selection?", newArray("Exclude my selection", "Only analyze my selection", "Analyze the whole image"), 2, 2, "Exclude my selection");
				Dialog.show();
				user_area_rev = Dialog.getRadioButton();
				if (matches(user_area_rev, "Exclude my selection")) user_area_rev = true;
				if (matches(user_area_rev, "Only analyze my selection")) user_area_rev = false;
				if (matches(user_area_rev, "Analyze the whole image")) {
					run("Select All");
					roiManager("Add");
					setBatchMode('hide');
					}
				else { //
					setTool("freehand");
					waitForUser("Press \"OK\" after selecting area for analysis\nSelect nothing to analyze the entire image");
					setBatchMode('hide');
					if (selectionType() >= 0 && selectionType() < 4) {
						if (user_area_rev == true) run("Make Inverse");
						roiManager("Add");
						}
					else {
						run("Select All");
						roiManager("Add");
						}
					}
				}
			else {
				run("Select All");
				roiManager("Add");
				}
				
			//Get Median Background Level
			SNR_background();
			back_median = getResult("Median", nResults - 1);
			run("Clear Results");
			
			//Determine Maxima
			selectImage(window_MaxIP);
			maxima = SNR_maximasearch();
			run("Clear Results");
			
			//Run peak intensity and Sum intensity measurments
			if (peak_intensity == true) {
				roiManager("Select", 0);
				run("Find Maxima...", "noise=" + maxima + " output=[Point Selection]");
				run("Measure");
				String.resetBuffer;
				String.append(path + ", ");
				for (n = 1; n < nResults; n++) String.append(getResult("Mean", n) + ", ");
				print("[Peak]", String.buffer);
				run("Find Maxima...", "noise=" + maxima + " output=List");
				}
			if (sum_intensity == true) {
				roiManager("Select", 0);
				run("Find Maxima...", "noise=" + maxima + " output=List");
				setResult("Sum Intensity", 0, 0);
				for (q = 0; q < nResults; q++) {
					selectImage(window_MaxIP);
					makeOval(getResult("X", q), getResult("Y", q), 5, 5);
					getRawStatistics(nPixels, mean, dummy, dummy, dummy, dumb);
					setResult("Sum Intensity", q, nPixels * mean);
					}
				String.resetBuffer;
				String.append(path + ", ");
				for (n = 1; n < nResults; n++) String.append(getResult("Sum Intensity", n) + ", ");
				print("[Sum]", String.buffer);
				}
			if (peak_intensity == false && sum_intensity == false) {
				run("Clear Results");
				roiManager("Select", 0);
				run("Find Maxima...", "noise=" + maxima + " output=List");
				}
			
			//Create signal mask image
			newImage("Signal", "8-bit white", width, height, 1); 
			selectWindow("Signal");
			window_signal = getImageID();
			
			//Initialize dot expansion
			setColor(0);
			spot_count = nResults;
			bad_spots = 0;
			x_values = newArray();
			y_values = newArray();
			cardinal = newArray();
			if (spotbyspot == true) {
				north = newArray();
				northeast = newArray();
				east = newArray();
				southeast = newArray();
				south = newArray();
				southwest = newArray();
				west = newArray();
				northwest = newArray();
				}
			for (q = 0; q < nResults; q++) {
				x_values = Array.concat(x_values, getResult("X", q));
				y_values = Array.concat(y_values, getResult("Y", q));
				}
			//Expand dots
			if (poly == false) { //Run the faster dots program
				for (q = 0; q < nResults; q++) {
					SNR_dots(x_values[q], y_values[q]); //Run dots with different x and y values
					}//End of dots loop
				}
			else { //Run the slower polygon program
				for (q = 0; q < x_values.length; q++) {
					cardinal = SNR_polygon(x_values[q], y_values[q], window_signal); //Run dots with different x and y values
					if (spotbyspot == true) {
						north = Array.concat(north, cardinal[0]);
						northeast = Array.concat(northeast, cardinal[1]);
						east = Array.concat(east, cardinal[2]);
						southeast = Array.concat(southeast, cardinal[3]);
						south = Array.concat(south, cardinal[4]);
						southwest = Array.concat(southwest, cardinal[5]);
						west = Array.concat(west, cardinal[6]);
						northwest = Array.concat(northwest, cardinal[7]);
						}
					}//End of dots loop
				}
			
			x_values_high = newArray();
			y_values_high = newArray();
			north_high = newArray();
			northeast_high = newArray();
			east_high = newArray();
			southeast_high = newArray();
			south_high = newArray();
			southwest_high = newArray();
			west_high = newArray();
			northwest_high = newArray();
			mean_intensity_high = newArray();
			
			if (spotbyspot == true) {
				selectImage(window_signal);
				close();
				mean_intensity = newArray();
				
				//Iterate through every spot and get mean
				selectImage(window_MaxIP);
				for (q = 0; q < x_values.length; q++) {
					run("Select None");
					makePolygon(x_values[q], y_values[q] + north[q], x_values[q] + northeast[q], y_values[q] + northeast[q], x_values[q] + east[q], y_values[q], x_values[q] + southeast[q], y_values[q] - southeast[q], x_values[q], y_values[q] - south[q], x_values[q] - southwest[q], y_values[q] - southwest[q], x_values[q] - west[q], y_values[q], x_values[q] - northwest[q], y_values[q] + northwest[q]);
					run("Measure");
					mean_intensity = Array.concat(mean_intensity, getResult("Mean", nResults - 1));
					//print(getResult("Mean", nResults-1));
					run("Clear Results");
					}
				
				//Calculate cutoffs
				temparr = newArray(); //temporary array
				temparr = Array.copy(mean_intensity); //temp array stores mean_intensity values
				Array.sort(temparr);
				med = 0; //median of mean_intensity
				madarr = newArray(); //median absolute deviation array
				mad = 0;
				if (temparr%2 == 0) { //If even
					temp = temparr.length/2;
					med =(temparr[temp] + temparr[temp+1])/2;
					}
				else { //Odd
					med = temparr[floor(temparr.length/2)+1];
					}
				//Median Absolute Deviation
				for (q = 0; q < mean_intensity.length; q++) {
					madarr = Array.concat(madarr, abs(med - mean_intensity[q]));
					}
				Array.sort(madarr);
				if (madarr%2 == 0) { //If even
					temp = madarr.length/2;
					mad =(madarr[temp] + madarr[temp+1])/2;
					}
				else mad = madarr[floor(madarr.length/2)+1]; //If odd
				
				made = mad * 1.483;
				
				low_cutoff = med - (made * low_user);
				high_cutoff = med + (made * high_user);
				
				low_counter = newArray();
				high_counter = newArray();
				
				//print(low_cutoff, high_cutoff);
				//print(temparr[0], temparr[temparr.length-1]);
				
				//Mask lowest
				for (q = 0; q < mean_intensity.length; q++) { //Select spots that should not be included in the regular measurement
					if (mean_intensity[q] < low_cutoff) {
						//print("Low " + mean_intensity[q] + " / " + low_cutoff);
						low_counter = Array.concat(low_counter, q); //Mask for low cutoff
						}
					else if (mean_intensity[q] > high_cutoff) {
						//print("High " + mean_intensity[q] + " / " + high_cutoff);
						high_counter = Array.concat(low_counter, q); //Add to array that will exclude points
						x_values_high = Array.concat(x_values_high, x_values[q]);
						y_values_high = Array.concat(y_values_high, y_values[q]);
						/*north_high = Array.concat(north_high, north[q]);
						northeast_high = Array.concat(northeast_high, northeast[q]);
						east_high = Array.concat(east_high, east[q]);
						southeast_high = Array.concat(southeast_high, southeast[q]);
						south_high = Array.concat(south_high, south[q]);
						southwest_high = Array.concat(southwest_high, southwest[q]);
						west_high = Array.concat(west_high, west[q]);
						northwest_high = Array.concat(northwest_high, northwest[q]);
						mean_intensity_high = Array.concat(mean_intensity_high, mean_intensity[q]);*/
						}
					//else print("Regular " + mean_intensity[q]);
					}
				
				newImage("Regular Signal", "8-bit white", width, height, 1); 
				selectWindow("Regular Signal");
				window_reg_signal = getImageID();
				

				newImage("High Signal", "8-bit white", width, height, 1); 
				selectWindow("High Signal");
				window_high_signal = getImageID();
				
				//Re-run Poly
				setColor(0);
				temp = count_bad;
				count_bad = true;
				for (q = 0; q < x_values_high.length; q++) {
					//print(x_values_high[q], y_values_high[q]);
					cardinal = SNR_polygon(x_values_high[q], y_values_high[q], window_high_signal); //Run poly with high xy values
					}
				count_bad = temp;
				
				for (q = 0; q < x_values.length; q++) {
					found = false;
					for (p = 0; p < low_counter.length; p++) {
						if (q == low_counter[p]) found = true;
						}
					if (found == false) cardinal = SNR_polygon(x_values[q], y_values[q], window_reg_signal); //Run poly with new x and y values, screen out low and high signal
					}
				
				print(x_values.length-low_counter.length + " Regular points processed");
				if (x_values_high.length > 0) print(x_values_high.length + " bright spots");
				if (bad_spots > 0) print(bad_spots + " bad points detected");
				
				selectImage(window_reg_signal);
				run("Create Selection");
				roiManager("Add");
				run("Make Inverse");
				roiManager("Add");
				selectImage(window_reg_signal);
				close();
				
				if (x_values_high.length > 0) {
					selectImage(window_high_signal);
					run("Create Selection");
					roiManager("Add");
					run("Make Inverse");
					roiManager("Add");
					selectImage(window_high_signal);
					close();
					}
				else {
					selectImage(window_high_signal);
					close();
					}
				
				//DEBUG
				//selectImage(window_MaxIP);
				//roiManager("Select", 2);
				//setBatchMode(false);
				//exit();
				//DEBUG
				
				
				//Regular Signal
				SNR_signal(1); //give regular signal
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Regular Signal");
				updateResults();
				
				//High Signal
				if (x_values_high.length > 0) {
					SNR_signal(3); //give high signal
					setResult("File", nResults - 1, path);
					setResult("Description", nResults - 1, "High Signal");
					updateResults();
					}
				
				//Run Noise
				if (x_values_high.length > 0) SNR_noise(1, 3); //Give inverse of regular and high signal
				else SNR_noise(2, 2);
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Cell Noise");
				updateResults();
				
				//Run Background
				SNR_background();
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Background");
				updateResults();
				}
			else {
				//Create Selection of signal
				print(nResults + " points processed");
				if (bad_spots > 0) print(bad_spots + " bad points detected");
				selectImage(window_signal);
				run("Create Selection");
				roiManager("Add"); //Create Signal selection
				run("Make Inverse"); //Make selection inverted
				roiManager("Add"); //Create Inverse Signal selection
				
				selectImage(window_signal);
				close();
				
				//Run signal
				SNR_signal(1);
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Signal");
				updateResults();
				
				//Run Noise
				SNR_noise(2, 2);
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Cell Noise");
				updateResults();
				
				//Run Background
				SNR_background();
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Background");
				updateResults();
				}
				
			//Results
			array_results = newArray();
			if (spotbyspot == true && x_values_high.length > 0) array_results = SNR_bright_results();
			else if (spotbyspot == true && x_values_high.length == 4) array_results = SNR_bright_results_null();
			else array_results = SNR_results();
			
			//Prep Images
			selectImage(window_MaxIP);
			run("Select None");
			setThreshold(0, 10000);
			run("Create Selection");
			resetThreshold();
			run("Enhance Contrast", "saturated=0.01"); //Make the MaxIP image pretty
			run("Select None");
			run("8-bit");
			if (spotbyspot == true && x_values_high.length > 0) drawString(path + "\nRegular SNR: " + array_results[0] + "\nBright SNR: " + array_results[3], 10, 40, 'white');
			else drawString(path + "\nSNR: " + array_results[0], 10, 40, 'white');
			selectImage(window_Median);
			run("Enhance Contrast", "saturated=0.01"); //Make the Median image pretty
			run("8-bit");
			if (spotbyspot == true && x_values_high.length > 0) drawString("Median Merge\nRegular Signal: " + array_results[1] + "\nBright Singal: " + array_results[4] + "\nNoise: " + array_results[2], 10, 40, 'white');
			else drawString("Median\nSignal: " + array_results[1] + "\nNoise: " + array_results[2], 10, 40, 'white');	
			
			//Add Slice with Cell Noise and Signal areas on it
			selectImage(window_MaxIP);
			run("Images to Stack", "name=Stack title=[] use");
			setSlice(1);
			run("Add Slice");
			//Color in Noise
			run("Select None");
			if (spotbyspot == true && x_values_high.length > 0) {
				roiManager("Select", newArray(0,2,4,5)); //Noise, inverse of regular signal and bright signal
				roiManager("AND");
				setColor(85);
				fill();
				run("Select None");
				roiManager("Select", 1); //Regular Signal
				setColor(170);
				fill();
				run("Select None");
				roiManager("Select", 3); //Bright Signal
				setColor(255);
				fill();
				run("Enlarge...", "enlarge=1 pixel");
				setForegroundColor(5, 5, 5);
				run("Draw", "slice");
				drawString("Maxima: " + maxima + "\nRegular Spots: " + spot_count + "/" + bad_spots + "\nBright Spots: " + x_values_high.length, 10, 40, 'white');
				}
			else {
				roiManager("Select", newArray(0,2,3));
				roiManager("AND");
				setColor(128);
				fill();
				run("Select None");
				roiManager("Select", 1);
				setColor(255);
				fill();
				drawString("Maxima: " + maxima + "\nSpots: " + spot_count + "/" + bad_spots, 10, 40, 'white');
				}
			if (user_area == true) {
				setForegroundColor(255, 255, 255);
				if (user_area_rev == false) {
					/*getSelectionBounds(x, y, width, height);
					x = x+width/2;
					y = y+height/2;
					setJustification("center");
					setFont("SansSerif", 12);*/
					for (k = 1; k < nSlices; k++) {
						setSlice(k);
						roiManager("Select", 0);
						run("Draw", "slice");
						//drawString("Excluded", x, y, 'white');
						}
					}
				else {
					for (k = 1; k < nSlices; k++) {
						setSlice(k);
						roiManager("Select", 0);
						run("Draw", "slice");
						}
					}
				}
			
			run("Select None");
			saveAs("tif	", outDir + stripath + "_Merge.tif");
			run("Close All");
			roiManager("Deselect");
			roiManager("Delete");
				
			}} //end of else
		}//end of for loop
	}//end of function

function SNR_background() { //Measures background, the darkest part, where there are no cells
	selectImage(window_Median);
	run("Select None");
	roiManager("Select", 0);
	setAutoThreshold("Default"); //Default is good for background (especially very dark cell noise)
	run("Create Selection");
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results
	} //End of Function

function SNR_noise(roi1, roi2) { //Measures Cell Noise, ensure dots and inverse dots are in the ROI manager, positions 0 and 1 respectively
	selectImage(window_Median);
	run("Select None");
	roiManager("Select", 0);
	setAutoThreshold("Default dark"); //Threshold cell noise
	run("Create Selection"); //Create selection 2
	run("Enlarge...", "enlarge=-1 pixel"); //Remove very small selections
	run("Enlarge...", "enlarge=11 pixel"); //Expand Cell noise boundary; Needed for exceptional images
	roiManager("Add");
	roiManager("Select", newArray(0, roi1, roi2, roiManager("Count") - 1)); //Select Inverse dots and Cell Noise
	roiManager("AND"); //Select regions of Cell Noise and inverse of dots
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results and clear ROI manager
	}//End of Noise function

function SNR_signal(roi) { //Measures Signal, ensure dots is in ROI manager, position 0
	selectImage(window_MaxIP);
	roiManager("Select", newArray(0, roi));
	roiManager("AND");
	run("Measure");
	run("Select None");
	} //End of signal function

function SNR_dots(xi, yi) { //Searches N, S, E, W and then draws an ellipse on mask image
	selectImage(window_MaxIP);
	bright = getPixel(xi,yi);
	cap = 0;
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance_bounding && r < 8; r++); //Progress r until there is a drop in brightness (>10% default)
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright > tolerance_bounding || getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++); //Progress r until there is no change in brightness (<10% default)
	x2 = xi + r; //right
	if (r >= 5) cap ++;
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance_bounding && r > -8; r--);
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r - 1, yi)/bright > tolerance_bounding || getPixel(xi + r, yi)/bright - getPixel(xi + r - 1, yi)/bright < - tolerance_bounding * tolerance_upward) && r > -15; r--);
	x1 = xi + r; //left
	if (r <= -5) cap ++;
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance_bounding && r < 8; r++);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright > tolerance_bounding || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++);
	y2 = yi + r; //top
	if (r >= 5) cap ++;
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance_bounding && r > -8; r--);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r - 1)/bright > tolerance_bounding || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r - 1)/bright < - tolerance_bounding * tolerance_upward) && r > -15; r--);
	y1 = yi + r; //bottom
	if (r <= -5) cap ++;
	
	w = x2-x1;
	h = y2-y1;
	
	if (cap <= 2 || count_bad == true) {
		selectImage(window_signal);
		fillOval(x1, y1, w, h);
		}
	else {
		spot_count --;
		bad_spots ++;
		}
	}//End of dot function

function SNR_polygon(xi, yi, window) { //Searches in eight cardinal directions and draws polygon on mask image
	selectImage(window_MaxIP);
	bright = getPixel(xi,yi) - back_median; //Get Relative brightness of brightest pixel
	cardinal = newArray(0, 0, 0, 0, 0, 0, 0, 0); //Array for directions
	cap = 0;
	r = 0;
	
	//North point
	//print("New Spot");
	for (r = 0; (getPixel(xi, yi + r) - back_median)/bright > tolerance_drop && r < 8; r++);; //Get Relative brightness of brightest pixel
	pixel = newArray();
	pixel_avg = 1;
	//print(pixel.length, pixel_avg);
	for (r = r; pixel_avg > tolerance_bounding && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi, yi + r) - back_median); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) { //Calculate the pixel_dif
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { //Get average of pixel_dif
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		//print(pixel.length, pixel_avg);
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[0] = r; 
	if (r >= 5) cap ++;

	//Northeast point
	for (r = 0; (getPixel(xi + r, yi + r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414 && r < 8; r++);; 
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414 && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi + r, yi + r) - back_median); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { 
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[1] = r; 
	if (r >= 5) cap ++;
	
	//East point
	for (r = 0; (getPixel(xi + r, yi) - back_median)/bright > tolerance_drop && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi + r, yi)); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { 
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[2] = r;
	if (r >= 5) cap ++;
	
	//Southeast point
	for (r = 0; (getPixel(xi + r, yi - r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414 && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414 && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi + r, yi - r) - back_median); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { 
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[3] = r;
	if (r >= 5) cap ++;
	
	//South Point
	for (r = 0; (getPixel(xi, yi - r) - back_median)/bright > tolerance_drop && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi, yi - r) - back_median); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { 
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[4] = r; 
	if (r >= 5) cap ++;
	
	//Southwest point
	for (r = 0; (getPixel(xi - r, yi - r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414 && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414 && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi - r, yi - r) - back_median); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { 
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[5] = r; 
	if (r >= 5) cap ++;
	
	//West point
	for (r = 0; (getPixel(xi - r, yi) - back_median)/bright > tolerance_drop && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi - r, yi)); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { 
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[6] = r;
	if (r >= 5) cap ++;
	
	//Northwest point
	for (r = 0; (getPixel(xi - r, yi + r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414 && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414 && r < 15; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, getPixel(xi - r, yi + r) - back_median); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/bright); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) { 
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	cardinal[7] = r;
	if (r >= 5) cap ++;
	
	
	if (cap <= 3 || count_bad == true) {
		selectImage(window);
		makePolygon(xi, yi + cardinal[0], xi + cardinal[1], yi + cardinal[1], xi + cardinal[2], yi, xi + cardinal[3], yi - cardinal[3], xi, yi - cardinal[4], xi - cardinal[5], yi - cardinal[5], xi - cardinal[6], yi, xi - cardinal[7], yi + cardinal[7]);
		//exit();
		fill();
		return cardinal;
		}
	else {
		spot_count --;
		bad_spots ++;
		return cardinal;
		}
	}//End of crazy polygon function

function SNR_maximasearch() { //Searches until the slope of the spot count levels out
	maxima = maxima_start;
	slope = newArray();
	slope_second = newArray();
	slope_second_avg = 1;
	run("Clear Results");
	//Initialize Maxima Results
	roiManager("Select", 0);
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	maxima += 5;
	
	//Second run
	roiManager("Select", 0);
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	maxima += 5;
	//Get first slope value
	slope = (getResult("Count", nResults - 1) - getResult("Count", nResults - 2));
	updateResults();
	do { //Loop until the slope of the count levels out
		//Get the next Spot Count
		roiManager("Select", 0);
		run("Find Maxima...", "noise=" + maxima + " output=Count");
		setResult("Maxima", nResults - 1, maxima);
		updateResults();
		
		//Add slopes to slope array
		slope = Array.concat(slope, getResult("Count", nResults - 1) - getResult("Count", nResults - 2));
		if (slope.length >= 6) slope = Array.slice(slope, 1, 6);
		maxima += 5;
		
		//Add second degree slopes to slope_second array
		slope_second = newArray();
		for (i = 1; i < slope.length; i++) slope_second = Array.concat(slope_second, abs(slope[i-1] - slope[i]));
		if (slope_second.length >= 5) slope_second = Array.slice(slope_second, 1, 5);
		
		Array.getStatistics(slope_second, dummy, dummy, slope_second_avg, dummy); //Get the average of slope_second
		//Debug
		//print("\nSlope");
		//Array.print(slope);
		//print("Slope_Second");
		//Array.print(slope_second);
		//print("slope__second_avg: " + slope_second_avg);
		} while (slope_second_avg > tolerance_maxima)  //Keep going as long as the average second_slope is greater than 4 (default)
	maxima -= slope.length * 2.5; //Once the condition has been met drop maxima back half the number of steps to make it the middle of the window
	updateResults();
	
	if (plot == true) { //Create plots for maxima results
		for (n = maxima + slope.length * 2.5; n < maxima + maxima - maxima_start + 10; n += 5) { //Continue measuring spots
			roiManager("Select", 0);
			run("Find Maxima...", "noise=" + n + " output=Count");
			setResult("Maxima", nResults - 1, n);
			updateResults(); //Not Required
			}
		
		start = nResults / 2 - 9;
		if (start < 0) start = 0;
		stop = nResults / 2 + 10;
		if (stop > nResults) stop = nResults;
		for (n = start; n < stop; n++) { //Add Maxima and Count values to an array
			xvalues = Array.concat(xvalues, getResult("Maxima", n));
			yvalues = Array.concat(yvalues, getResult("Count", n));
			}
		xvalues = Array.slice(xvalues, 1, xvalues.length - 1); //Remove first x value
		yvalues = Array.slice(yvalues, 1, yvalues.length - 1); //Remove first y value
		Plot.create("Plot", "Maxima", "Count", xvalues, yvalues); //Make plot
		Plot.drawLine(maxima, yvalues[yvalues.length - 1], maxima, yvalues[0]); //Draw vertical line at maxima
		Plot.show();
		selectWindow("Plot");
		saveAs("PNG", outDir + "\\Plots\\" + stripath); //Save plot
		close();
		}
	updateResults();
	return maxima;
	}

function SNR_results() { //String Manipulation and Saves results to tables
	//Calculate signal to noise ratio and other values
	signoimean = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	signoimedian = (getResult("Median", nResults - 3) - getResult("Median", nResults - 1)) / (getResult("Median", nResults - 2) - getResult("Median", nResults - 1)); //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	sigrel = getResult("Median", nResults - 3) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	cv = getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3); //Coefficient of Variation - Signal
	
	//Set results
	for (m = 1; m <= 3; m++) { //Calculate CV for each selection
		setResult("Coefficient of Variation", nResults - m, getResult("StdDev", nResults - m) / getResult("Mean", nResults - m));
		}
	setResult("Mean SNR", nResults - 3, signoimean);
	setResult("Median SNR", nResults - 3, signoimedian);
	setResult("Signal", nResults - 3, sigrel);
	setResult("Noise", nResults - 3, noirel);
	setResult("Spots", nResults - 3, spot_count);
	setResult("Bad Spots", nResults - 3, bad_spots);
	setResult("Maxima", nResults - 3, maxima);
	
	//Set Warnings
	/*Warning Codes
	1 = Low spot count (Suspicious)
	2 = Maxima is too high
	4 = Largely Bound Spots
	8 = Bad Coefficient of Variation (> 0.15 for Noise and Background)
	*/
	warnings = 0;
	temp = 0;
	for (m = 1; m <= 2; m++) { //If the Coefficient of Variation for Noise or Background is greater than 0.2(default) then warn user
		if (getResult("Coefficient of Variation", nResults - m) > warning_cvnoise && warning_disable == false) {
			setResult("Warning Code", nResults - m, "High CV");
			temp = 1;
			}
		}
	if (cv > warning_cvspot || temp == 1) warnings += 8; //Check cv for
	if (getResult("Spots", nResults - 3) < warning_spot) warnings += 1;
	if (getResult("Bad Spots", nResults - 3) > warning_badspot) warnings += 4;
	if (maxima_start == maxima) warnings += 2;
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 3, warnings);
	updateResults();
	
	//String manipulation and saving to SNR table
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[SNR]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	//Save Condensed Results
	setResult("File", nResults, path);
	setResult("Mean SNR", nResults - 1, signoimean);
	setResult("Median SNR", nResults - 1, signoimedian);
	setResult("Signal", nResults - 1, sigrel);
	setResult("Noise", nResults - 1, noirel);
	setResult("Spots", nResults - 1, spot_count);
	setResult("Bad Spots", nResults - 1, bad_spots);
	setResult("Maxima", nResults - 1, maxima);
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 1, warnings);
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	return newArray(signoimedian, sigrel, noirel);
	}

function SNR_bright_results() { //String Manipulation and Saves results to tables
	//REGULAR SPOTS
	//Calculate signal to noise ratio and other values
	signoimean = (getResult("Mean", nResults - 4) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	signoimedian = (getResult("Median", nResults - 4) - getResult("Median", nResults - 1)) / (getResult("Median", nResults - 2) - getResult("Median", nResults - 1)); //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	sigrel = getResult("Median", nResults - 4) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	cv = getResult("StdDev", nResults - 4) / getResult("Mean", nResults - 4); //Coefficient of Variation - Signal
	
	//BRIGHT SPOTS
	signoimedian_bright = (getResult("Median", nResults - 3) - getResult("Median", nResults - 1)) / (getResult("Median", nResults - 2) - getResult("Median", nResults - 1)); //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	sigrel_bright = getResult("Median", nResults - 3) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel_bright = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	
	//Set results

	setResult("Coefficient of Variation", nResults - 1, getResult("StdDev", nResults - 1) / getResult("Mean", nResults - 1)); //Background CV
	setResult("Coefficient of Variation", nResults - 2, getResult("StdDev", nResults - 2) / getResult("Mean", nResults - 2)); //Noise CV
	setResult("Coefficient of Variation", nResults - 4, getResult("StdDev", nResults - 4) / getResult("Mean", nResults - 4)); //Regular Signal CV
	setResult("Mean SNR", nResults - 4, signoimean);
	setResult("Median SNR", nResults - 4, signoimedian);
	setResult("Median SNR", nResults - 3, signoimedian_bright);
	setResult("Signal", nResults - 4, sigrel);
	setResult("Signal", nResults - 3, sigrel_bright);
	setResult("Noise", nResults - 4, noirel);
	setResult("Spots", nResults - 4, spot_count);
	setResult("Bad Spots", nResults - 4, bad_spots);
	setResult("Maxima", nResults - 4, maxima);
	
	//Set Warnings
	/*Warning Codes
	1 = Low spot count (Suspicious)
	2 = Maxima is too high
	4 = Largely Bound Spots
	8 = Bad Coefficient of Variation (> 0.15 for Noise and Background)
	*/
	warnings = 0;
	temp = 0;
	for (m = 1; m <= 2; m++) { //If the Coefficient of Variation for Noise or Background is greater than 0.2(default) then warn user
		if (getResult("Coefficient of Variation", nResults - m) > warning_cvnoise && warning_disable == false) {
			setResult("Warning Code", nResults - m, "High CV");
			temp = 1;
			}
		}
	if (cv > warning_cvspot || temp == 1) warnings += 8; //Check cv for
	if (getResult("Spots", nResults - 4) < warning_spot) warnings += 1;
	if (getResult("Bad Spots", nResults - 4) > warning_badspot) warnings += 4;
	if (maxima_start == maxima) warnings += 2;
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 4, warnings);
	updateResults();
	
	//String manipulation and saving to SNR table
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[SNR]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	//Save Condensed Results
	setResult("File", nResults, path);
	setResult("Mean SNR", nResults - 1, signoimean);
	setResult("Median SNR", nResults - 1, signoimedian);
	setResult("Bright Median SNR", nResults - 1, signoimedian_bright);
	setResult("Signal", nResults - 1, sigrel);
	setResult("Bright Signal", nResults - 1, sigrel_bright);
	setResult("Noise", nResults - 1, noirel);
	setResult("Spots", nResults - 1, spot_count);
	setResult("Bad Spots", nResults - 1, bad_spots);
	setResult("Maxima", nResults - 1, maxima);
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 1, warnings);
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	return newArray(signoimedian, sigrel, noirel, signoimedian_bright, sigrel_bright);
	}

function SNR_bright_results_null() { //String Manipulation and Saves results to tables
	//REGULAR SPOTS
	//Calculate signal to noise ratio and other values
	signoimean = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	signoimedian = (getResult("Median", nResults - 3) - getResult("Median", nResults - 1)) / (getResult("Median", nResults - 2) - getResult("Median", nResults - 1)); //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	sigrel = getResult("Median", nResults - 3) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	cv = getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3); //Coefficient of Variation - Signal
	
	//BRIGHT SPOTS
	signoimedian_bright = 0;
	sigrel_bright = 0;
	noirel_bright = 0;
	
	//Set results

	setResult("Coefficient of Variation", nResults - 1, getResult("StdDev", nResults - 1) / getResult("Mean", nResults - 1)); //Background CV
	setResult("Coefficient of Variation", nResults - 2, getResult("StdDev", nResults - 2) / getResult("Mean", nResults - 2)); //Noise CV
	setResult("Coefficient of Variation", nResults - 3, getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3)); //Regular Signal CV
	setResult("Mean SNR", nResults - 3, signoimean);
	setResult("Median SNR", nResults - 3, signoimedian);
	setResult("Signal", nResults - 3, sigrel);
	setResult("Noise", nResults - 3, noirel);
	setResult("Spots", nResults - 3, spot_count);
	setResult("Bad Spots", nResults - 3, bad_spots);
	setResult("Maxima", nResults - 3, maxima);
	
	//Set Warnings
	/*Warning Codes
	1 = Low spot count (Suspicious)
	2 = Maxima is too high
	4 = Largely Bound Spots
	8 = Bad Coefficient of Variation (> 0.15 for Noise and Background)
	*/
	warnings = 0;
	temp = 0;
	for (m = 1; m <= 2; m++) { //If the Coefficient of Variation for Noise or Background is greater than 0.2(default) then warn user
		if (getResult("Coefficient of Variation", nResults - m) > warning_cvnoise && warning_disable == false) {
			setResult("Warning Code", nResults - m, "High CV");
			temp = 1;
			}
		}
	if (cv > warning_cvspot || temp == 1) warnings += 8; //Check cv
	if (getResult("Spots", nResults - 3) < warning_spot) warnings += 1;
	if (getResult("Bad Spots", nResults - 3) > warning_badspot) warnings += 4;
	if (maxima_start == maxima) warnings += 2;
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 3, warnings);
	updateResults();
	
	//String manipulation and saving to SNR table
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[SNR]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	//Save Condensed Results
	setResult("File", nResults, path);
	setResult("Mean SNR", nResults - 1, signoimean);
	setResult("Median SNR", nResults - 1, signoimedian);
	setResult("Bright Median SNR", nResults - 1, signoimedian_bright);
	setResult("Signal", nResults - 1, sigrel);
	setResult("Bright Signal", nResults - 1, sigrel_bright);
	setResult("Noise", nResults - 1, noirel);
	setResult("Spots", nResults - 1, spot_count);
	setResult("Bad Spots", nResults - 1, bad_spots);
	setResult("Maxima", nResults - 1, maxima);
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 1, warnings);
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	return newArray(signoimedian, sigrel, noirel, signoimedian_bright, sigrel_bright);
	}

print("-- Done --");
showStatus("Finished.");
}//end of macro