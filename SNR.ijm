
macro "Calculate Signal to Noise Ratio v0.4.3...[c]" {
version = "0.4.3";
/*
2015-3-18
For in-house use only, do not distribute
Written by Trevor Okamoto, Research Associate, Stellaris. Biosearch Technologies, Inc.

ImageJ/Fiji Macro for analyzing single molecule RNA FISH images from a Nikon Eclipse
Separates the Signal from the surrounding cellular noise, and the background from the cellular noise.  These segments are measured for their mean and median brightness values.  These values are used to calculate the relative singal and noise, and from that the signal to noise ratio.  Other options are available such as spot filtering, and tolerance tweaking.
This macro opens a directory and does an analysis of spots
Based off of "TrevorsMeasure" or "Measure Dots..."
Uses Find Maxima to find spots and expand the points to a selection used for spot analysis
Use the Default threshold to determine cell noise and background values

In regards to Significant Figures
	All pixels are treated as exact numbers, results are capped to three decimal places, however the limiting sigfig is 10

Tested on ImageJ version 1.49o, 1.48v
!!!1.49n does not work as intended!!!
*/

//Initialize
setBatchMode(true);
setOption("ShowRowNumbers", false);
requires("1.48v");
run("Set Measurements...", "area mean standard min median redirect=None decimal=3");
run("Input/Output...", "jpeg=85 gif=-1 file=.csv save_column");
setFont("SansSerif", 22);
print("\\Clear");
run("Clear Results");
run("Close All");



if (indexOf(getVersion(), "1.49n") > -1) {
	Dialog.create("Incompatible ImageJ Version");
	Dialog.addMessage("You are using ImageJ version 1.49n, which is incompatible with this macro.\n \nUpgrade your ImageJ version by going to \"Help\" > \"Update ImageJ\".");
	Dialog.addCheckbox("I want to do it anyway", false);
	Dialog.show();
	temp = Dialog.getCheckbox();
	if (temp == false) exit("Upgrade by going to \"Help\" > \"Update ImageJ\" and selecting \"Previous\"");
	}


//Default Variables
tolerance_bounding = 0.25; //Tolerance for ellipse bounding. Higher means smaller ellipsis 
tolerance_upward = 0.8; //Tolerates upward movement (0 means any upward movement will be tolerated, 1 means tolerance will be the same as downward movement)
maxima = 20;
expansion_method = "Normal";
tolerance_maxima = 5;
sum_intensity = false;
peak_intensity = false;
plot = false;
filter = false;
user_area = false;
rsquare = false;
user_area_rev = false;
//Advanced Options
advanced = false;
delay = 0;
output = "Out-SNRatio";
objective = 60;
count_bad = true;
warning_cvspot = 0.5;
warning_cvnoise = 0.25;
warning_spot = 100;
warning_badspot = 30;
warning_disable = false;
exclude = "NULL";
low_user = 2.5;
high_user = 4;
gauss_offset = 2; //Limit for standard deviation
gauss_d = 2; //Number of standard deviations to move outward


//Dialog
Dialog.create("Spot Processor");

Dialog.addMessage("Please enter the Bounding Stringency, Upward Stringency and Maxima Tolerance");
Dialog.addSlider("Bounding Stringency(Higher = smaller spots):", 0.01, 0.5, tolerance_bounding);
Dialog.addSlider("Upward Stringency(Higher = smaller spots):", 0, 1, tolerance_upward);
Dialog.addSlider("Starting Maxima(Higher = faster):", 0, 200, maxima);
Dialog.addSlider("Maxima Tolerance(Higher = More Spots):", 1, 50, tolerance_maxima);
Dialog.addChoice("Signal Masking Option:", newArray("Normal", "Force Polygon", "Gaussian"));
Dialog.addCheckboxGroup(2, 3, newArray("Sum Intensity", "Peak Intensity", "Plot Maxima Results", "User Defined Area", "Signal Filtering", "Advanced Options"), newArray(sum_intensity, peak_intensity, plot, user_area, filter, advanced));
Dialog.show();

//Retrieve Choices
tolerance_bounding = Dialog.getNumber();
tolerance_upward = Dialog.getNumber();
maxima = Dialog.getNumber();
tolerance_maxima = Dialog.getNumber();
expansion_method = Dialog.getChoice();
sum_intensity = Dialog.getCheckbox();
peak_intensity = Dialog.getCheckbox();
plot = Dialog.getCheckbox();
user_area = Dialog.getCheckbox();
filter = Dialog.getCheckbox();
advanced = Dialog.getCheckbox();
maxima_start = maxima;
tolerance_drop = (tolerance_bounding / 5) + 0.89;

//Warn if Choices are outside of recommended range
if (tolerance_bounding > 0.3 || tolerance_bounding < 0.2 || tolerance_upward < 0.5 || tolerance_maxima > 10 || tolerance_maxima < 2 || maxima > 50) {
	Dialog.create("Warning");
	Dialog.addMessage("One or more of your variables are outside of the recommended ranges.\nPlease refer to the recommended ranges below.");
	Dialog.addMessage("Bounding Stringency: 0.2 - 0.3  (" + tolerance_bounding + ")\nUpward Stringency: 0.5 - 1.0  (" + tolerance_upward + ")\nStarting Maxima: 0 - 50  (" + maxima + ")\nMaxima Stringency: 2 - 10  (" + tolerance_maxima + ")");
	Dialog.addMessage("If you would like to continue using these variables press \"OK\" to continue\nBe sure to check the merged tif files and warning codes in the results file to ensure the analysis was done correctly");
	Dialog.show();
	}

if (advanced == true) { //Advanced Options Dialog
	//waitForUser("Some advanced options will break the macro\nOnly change settings if you know what you're doing\n\nSome settings have not been fully implemented yet and are placeholders at the moment");
	
	Dialog.create("Advanced Options");
	Dialog.addString("Output Folder Name:", output);
	Dialog.addString("Exclude Files and Folders:", exclude);
	Dialog.addChoice("Objective Magnification", newArray(60, 100));
	Dialog.addSlider("Tolerance Drop", 0.5, 1, tolerance_drop);
	Dialog.addSlider("MADe Bottom", 1, 5, low_user);
	Dialog.addSlider("MADe Top", 1, 5, high_user);
	Dialog.addSlider("Network Delay", 0, 10, delay);
	Dialog.addCheckboxGroup(2, 2, newArray("Include Large Spots", "Disable Warning Codes", "Linear Fit Maxima Search(Experimental)"), newArray(count_bad, warning_disable, rsquare));
	Dialog.addMessage("Warning Cutoffs");
	Dialog.addSlider("Coefficient of Variation S", 0, 2, warning_cvspot);
	Dialog.addSlider("Coefficient of Variation N", 0, 2, warning_cvnoise);
	Dialog.addSlider("Suspicious Spot Count", 0, 200, warning_spot);
	Dialog.addSlider("Filtered Spot Count", 0, 50, warning_badspot);
	Dialog.show();
	
	output = Dialog.getString();
	exclude = Dialog.getString();
	objective = Dialog.getChoice();
	objective /= 60;
	objective = 1 / objective;
	tolerance_drop = Dialog.getNumber();
	low_user = Dialog.getNumber();
	high_user = Dialog.getNumber();
	delay = Dialog.getNumber();
	count_bad = Dialog.getCheckbox();
	warning_disable = Dialog.getCheckbox();
	rsquare = Dialog.getCheckbox();
	warning_cvspot = Dialog.getNumber();
	warning_cvnoise = Dialog.getNumber();
	warning_spot = Dialog.getNumber();
	warning_badspot = Dialog.getNumber();
	}

if (rsquare == true && filter == false) filter = getBoolean("Linear Fit Maxima Search works best with \"Signal Filtering\".\nEnable \"Signal Filtering?\"");
	
//Open Tables
run("Table...", "name=SNR width=400 height=200");
if (peak_intensity == true) run("Table...", "name=Peak width=400 height=200");
if (sum_intensity == true) run("Table...", "name=Sum width=400 height=200");
run("Table...", "name=Condense width=400 height=200");

//Write table headers
table_head = "Version " + version + " Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " " + expansion_method;
print("[SNR]", table_head);
print("[Condense]", table_head);

//Write Table Labels
table_head = "Area, Mean, StdDev, Min, Max, Median, File, Description, Coefficient of Variation, Score, Mean SNR, Median SNR, Signal, Noise, Spots, Filtered Spots, Maxima, Expansion Method";
if (warning_disable == false) table_head += "Warning Code";
print("[SNR]", table_head);

if (filter == true) table_head = "File, Score, Bright Score, Mean SNR, Median SNR, Bright Median SNR, Signal, Bright Signal, Noise, Spots, Filtered Spots, Maxima, Expansion Method";
else table_head = "File, Score, Mean SNR, Median SNR, Signal, Noise, Spots, Filtered Spots, Maxima, Expansion Method";
if (warning_disable == false) table_head += ", Warning Code";
print("[Condense]", table_head);


//Initialize Peak and Sum intensity tables
if (peak_intensity == true) print("[Peak]", "Peak Brightness");
if (sum_intensity == true) print("[Sum]", "Sum Intensity");

//Create Directories
output_name = "Results " + expansion_method + " " + tolerance_bounding + "-" + tolerance_upward + "-" + tolerance_maxima;
if (filter == true) output_name += "-filtered-" + low_user + "-" + high_user;
if (user_area == true) output_name += "-selection_" + toHex(random*random*random*1000) + toHex(random*random*random*1000);

dir = getDirectory("Choose Directory containing .nd2 files"); //Get directory
outDir = dir + output + "\\"; //Create base output directory
File.makeDirectory(outDir); //Create base output directory
outDir = outDir + output_name + "\\";//Create specific output directory
File.makeDirectory(outDir); //Create specific output directory
if (plot == true) File.makeDirectory(outDir + "\\Plots\\"); //Create Plots directory


//RUN IT!
total_start = getTime();
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

total_time = newArray();
total_time = SNR_timediff(total_start, getTime()); //Get total_time array for days, hours, and minutes difference
natural_time = SNR_natural_time("Total Time Elapsed: ", total_time); //Get natural spoken time string
print(natural_time);


print("-- Done --");
showStatus("Finished.");
}//end of macro

function SNR_main(dir, sub) {
	run("Bio-Formats Macro Extensions");
	list = getFileList(dir + sub);//get file list
	start_time = getTime();
	n = 0;
	for (i = 0;i < list.length; i++){ //for each file
		showProgress(1 / list.length - 1);
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
			reduced_cardinal = false;
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
				user_area_rev = getBoolean("Click \"Yes\" to analyze all but your selection\nPress \"No\" to analyze only your selection\n \Click \"Yes\" and make no selection to analyze the entire image");
				setTool("freehand");
				waitForUser("Click \"OK\" after selecting area for analysis\nSelect nothing to analyze the entire image");
				setBatchMode('hide');
				if ((selectionType() >= 0 && selectionType() < 4) || selectionType == 9) {
					if (user_area_rev == true) run("Make Inverse");
					roiManager("Add");
					}
				else {
					run("Select All");
					roiManager("Add");
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
			selectImage(window_MaxIP);
			roiManager("Select", 0);
			run("Clear Results");
			
			//Run peak intensity and Sum intensity measurments
			if (peak_intensity == true) {
				roiManager("Select", 0);
				run("Find Maxima...", "noise=" + maxima + " output=[Point Selection]");
				run("Measure");
				String.resetBuffer;
				String.append(path);
				for (n = 1; n < nResults; n++) String.append(", " + getResult("Mean", n));
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
				String.append(path);
				for (n = 1; n < nResults; n++) String.append(", " + getResult("Sum Intensity", n));
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
			filtered_spots = 0;
			x_values = newArray();
			y_values = newArray();
			cardinal = newArray();
			if (filter == true) {
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
			if (expansion_method == "Gaussian") { //If gaussian is selected run the gaussian fitting
				reduced_cardinal = true;
				for (q = 0; q < x_values.length; q++) {
					cardinal = SNR_gaussian(x_values[q], y_values[q], window_signal); //Run dots with different x and y values
					if (filter == true) {
						north = Array.concat(north, cardinal[0]);
						northeast = Array.concat(northeast, 0);
						east = Array.concat(east, cardinal[1]);
						southeast = Array.concat(southeast, 0);
						south = Array.concat(south, cardinal[2]);
						southwest = Array.concat(southwest, 0);
						west = Array.concat(west, cardinal[3]);
						northwest = Array.concat(northwest, 0);
						}
					} //End of dots loop
				}
			else if (x_values.length > 5000 && expansion_method == "Normal") { //Run the faster dots program if there's too many dots
				reduced_cardinal = true;
				for (q = 0; q < x_values.length; q++) {
					cardinal = SNR_dots(x_values[q], y_values[q], window_signal); //Run dots with different x and y values
					if (filter == true) {
						north = Array.concat(north, cardinal[0]);
						northeast = Array.concat(northeast, 0);
						east = Array.concat(east, cardinal[1]);
						southeast = Array.concat(southeast, 0);
						south = Array.concat(south, cardinal[2]);
						southwest = Array.concat(southwest, 0);
						west = Array.concat(west, cardinal[3]);
						northwest = Array.concat(northwest, 0);
						}
					} //End of dots loop
				}
			else { //Force polygon or if running on normal and less than 5000
				for (q = 0; q < x_values.length; q++) {
					cardinal = SNR_polygon(x_values[q], y_values[q], window_signal); //Run dots with different x and y values
					if (filter == true) {
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
			
			if (filter == true) { //Filter spots based on MADe settings
				selectImage(window_signal);
				close();
				mean_intensity = newArray();
				
				//Iterate through every spot and get mean
				selectImage(window_MaxIP);
				for (q = 0; q < x_values.length; q++) {
					run("Select None");
					if (reduced_cardinal == false) makePolygon(x_values[q], y_values[q] + north[q], x_values[q] + northeast[q], y_values[q] + northeast[q], x_values[q] + east[q], y_values[q], x_values[q] + southeast[q], y_values[q] - southeast[q], x_values[q], y_values[q] - south[q], x_values[q] - southwest[q], y_values[q] - southwest[q], x_values[q] - west[q], y_values[q], x_values[q] - northwest[q], y_values[q] + northwest[q]);
					else makeOval(x_values[q] - west[q], y_values[q] + north[q], east[q] + west[q], north[q] + south[q]);
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
						filtered_spots++;
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
				if (filtered_spots > 0) print(filtered_spots + " bad points detected");
				
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
				if (x_values_high.length > 0) SNR_noise(); //Give inverse of regular and high signal
				else SNR_noise();
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Cell Noise");
				updateResults();
				
				//Run Background
				SNR_background();
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Background");
				updateResults();
				}
			else { //Do not filter spots
				//Create Selection of signal
				print(nResults + " points processed");
				if (filtered_spots > 0) print(filtered_spots + " bad points detected");
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
				SNR_noise();
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
			if (filter == true && x_values_high.length > 0) array_results = SNR_bright_results(); //If doing spot by spot and there are bright spots
			else if (filter == true && x_values_high.length == 0) array_results = SNR_bright_results_null(); //If doing spot by spot and there are no bright spots
			else array_results = SNR_results(); //If not doing spot by spot
			
			//Prep Images
			selectImage(window_MaxIP);
			run("Select None");
			setThreshold(0, 10000);
			run("Create Selection");
			resetThreshold();
			run("Enhance Contrast", "saturated=0.01"); //Make the MaxIP image pretty
			run("Select None");
			run("8-bit");
			if (filter == true && x_values_high.length > 0) drawString(path + "\nRegular SNR/Score: " + array_results[0] + "/" + array_results[0] * array_results[1] / 100 + "\nBright SNR/Score: " + array_results[3] + "/" + array_results[3] * array_results[4] / 100, 10, 40, 'white');
			else drawString(path + "\nSNR/Score: " + array_results[0] + "/" + array_results[0] * array_results[1] / 100, 10, 40, 'white');
			selectImage(window_Median);
			run("Enhance Contrast", "saturated=0.01"); //Make the Median image pretty
			run("8-bit");
			if (filter == true && x_values_high.length > 0) drawString("Median Merge\nRegular Signal: " + array_results[1] + "\nBright Singal: " + array_results[4] + "\nNoise: " + array_results[2], 10, 40, 'white');
			else drawString("Median\nSignal: " + array_results[1] + "\nNoise: " + array_results[2], 10, 40, 'white');	
			
			//Add Slice with Cell Noise and Signal areas on it
			selectImage(window_MaxIP);
			run("Images to Stack", "name=Stack title=[] use");
			setSlice(1);
			run("Add Slice");
			//Color in Noise
			run("Select None");
			if (filter == true && x_values_high.length > 0) {
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
				drawString("Maxima: " + maxima + "\nRegular Spots: " + spot_count + "/" + filtered_spots + "\nBright Spots: " + x_values_high.length, 10, 40, 'white');
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
				drawString("Maxima: " + maxima + "\nSpots: " + spot_count + "/" + filtered_spots, 10, 40, 'white');
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
				run("Reverse");
				}
			
			run("Select None");
			saveAs("tif	", outDir + stripath + "_Merge.tif");
			run("Close All");
			roiManager("Deselect");
			roiManager("Delete");
			
			wait(delay*1000); //Delay for network
			
			remaining = list.length - i;
			estimate = round((getTime() - start_time) * remaining / (list.length - remaining));
			if (estimate < 259200000) {
				estimate_array = SNR_timediff(0, estimate);
				if (sub == "") folder = "\"Root\"";
				else folder = "\"" + substring(sub, 0, lengthOf(sub) - 1) + "\"";
				print(SNR_natural_time(folder + " Folder Time Remaining: ", estimate_array));
				}
			}} //end of else
		}//end of for loop
	
	}//end of main function

function SNR_background() { //Measures background, the darkest part, where there are no cells
	selectImage(window_Median);
	run("Select None");
	roiManager("Select", 0);
	setAutoThreshold("Default"); //Default is good for background (especially very dark cell noise)
	run("Create Selection");
	run("Enlarge...", "enlarge=1 pixel");
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results
	} //End of Function

function SNR_noise() { //Measures Cell Noise
	selectImage(window_Median);
	run("Select None");
	roiManager("Select", 0);
	setAutoThreshold("Default dark"); //Threshold cell noise
	run("Create Selection"); //Create selection 2
	run("Enlarge...", "enlarge=-1 pixel"); //Remove very small selections
	run("Enlarge...", "enlarge=11 pixel"); //Expand Cell noise boundary; Needed for exceptional images
	roiManager("Add");
	roiManager("Select", newArray(0, roiManager("Count") - 1)); //Select Cell Noise
	roiManager("AND"); //Select regions of Cell Noise
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results and clear ROI manager
	}//End of Noise function

function SNR_signal(roi) { //Measures Signal, ensure dots is in ROI manager, position 0
	selectImage(window_MaxIP);
	roiManager("Select", newArray(0, roi));
	roiManager("AND");
	/*
	selectImage(window_MaxIP);
	setBatchMode('show');
	waitForUser("test");
	setBatchMode('hide');
	*/
	run("Measure");
	run("Select None");
	} //End of signal function

function SNR_dots(xi, yi, window) { //Searches N, S, E, W and then draws an ellipse on mask image
	selectImage(window_MaxIP);
	bright = getPixel(xi,yi) - back_median;
	cardinal = newArray(0, 0, 0, 0); //Array for directions
	cap = 0;
	
	//North Point
	for (r = 0; (getPixel(xi, yi + r) - back_median)/bright > tolerance_drop && r < 8; r++); //Get Relative brightness of brightest pixel
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
	cardinal[1] = r;
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
	cardinal[2] = r; 
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
	cardinal[3] = r;
	if (r >= 5) cap ++;
	
	if (cap <= 2 || count_bad == true) {
		selectImage(window);
		fillOval(xi - cardinal[3], yi + cardinal[0], cardinal[1] + cardinal[3], cardinal[0] + cardinal[2]);
		return cardinal;
		}
	else {
		spot_count --;
		filtered_spots ++;
		return cardinal;
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
	for (r = 0; (getPixel(xi, yi + r) - back_median)/bright > tolerance_drop && r < 8; r++); //Get Relative brightness of brightest pixel
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
	for (r = 0; (getPixel(xi + r, yi + r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414213562 && r < 8; r++);; 
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414213562 && r < 15; r++) {
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
	for (r = 0; (getPixel(xi + r, yi - r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414213562 && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414213562 && r < 15; r++) {
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
	for (r = 0; (getPixel(xi - r, yi - r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414213562 && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414213562 && r < 15; r++) {
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
	for (r = 0; (getPixel(xi - r, yi + r) - back_median)/bright > tolerance_drop + (1 - tolerance_drop ) / 1.414213562 && r < 8; r++);;
	pixel = newArray();
	pixel_avg = 1;
	for (r = r; pixel_avg > tolerance_bounding * 1.414213562 && r < 15; r++) {
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
		filtered_spots ++;
		return cardinal;
		}
	}//End of crazy polygon function

function SNR_gaussian_search(pixels, cardinal, xory) { //Does the gaussian fit
	counting = newArray(-2, -1, 0, 1, 2);
	Fit.doFit(12, counting, pixels);
	if (xory == 0) {
		cardinal[1] = Fit.p(2) + (Fit.p(3) * gauss_d);
		cardinal[3] = (Fit.p(3) * gauss_d) - Fit.p(2);
		}
	else {
		cardinal[2] = Fit.p(2) + (Fit.p(3) * gauss_d);
		cardinal[0] = (Fit.p(3) * gauss_d) - Fit.p(2);
		}
	
	for (r = 0; Fit.p(3) > gauss_offset && r < 15; r ++) {
		//Array.print(pixels); //Debug
		if (xory == 0) {
			if (getPixel(xi-3-r, yi) < getPixel(xi-2-r, yi)) {
				pixels = Array.concat(pixels, getPixel(xi-3-r, yi));
				counting = Array.concat(counting, -3-r);
				}
			if (getPixel(xi+3+r, yi) < getPixel(xi+2+r, yi)) {
				pixels = Array.concat(pixels, getPixel(xi+3+r, yi));
				counting = Array.concat(counting, 3+r);
				}
			}
		else {
			if (getPixel(xi, yi-3-r) < getPixel(xi, yi-2-r)) {
				pixels = Array.concat(pixels, getPixel(xi, yi-3-r));
				counting = Array.concat(counting, -3-r);
				}
			if (getPixel(xi, yi+3+r) < getPixel(xi, yi+2+r)) {
				pixels = Array.concat(pixels, getPixel(xi, yi+3+r));
				counting = Array.concat(counting, 3+r);
				}
			}
		Fit.doFit(12, counting, pixels);
		if (Fit.p(3) < 2) {
			if (xory == 0) {
				cardinal[1] = Fit.p(2) + (Fit.p(3) * gauss_d);
				cardinal[3] = (Fit.p(3) * gauss_d) - Fit.p(2);
				}
			else {
				cardinal[2] = Fit.p(2) + (Fit.p(3) * gauss_d);
				cardinal[0] = (Fit.p(3) * gauss_d) - Fit.p(2);
				}
			}
		else {
			Array.fill(cardinal, 0);
			}
		}
	//print(Fit.p(2)); //Debug
	if (Fit.p(3) < 2) return Fit.p(2);
	else return 0;
	}

function SNR_gaussian(xi, yi, window) { //Finds sub pixel location of signal and draws a circle around that sub pixel area
	selectImage(window_MaxIP);
	cardinal = newArray(0, 0, 0, 0); //X and Y offsets
	cap = 0;
	
	//X Search
	x_bright = getPixel(xi-2, yi);
	x_bright = Array.concat(x_bright, getPixel(xi-1, yi));
	x_bright = Array.concat(x_bright, getPixel(xi, yi));
	x_bright = Array.concat(x_bright, getPixel(xi+1, yi));
	x_bright = Array.concat(x_bright, getPixel(xi+2, yi));
	x_center = SNR_gaussian_search(x_bright, cardinal, 0);
	//print("X: " + Fit.p(3)); //Debug
	yi += x_center;
	//Y Search
	y_bright = getPixel(xi, yi-2);
	y_bright = Array.concat(y_bright, getPixel(xi, yi-1));
	y_bright = Array.concat(y_bright, getPixel(xi, yi));
	y_bright = Array.concat(y_bright, getPixel(xi, yi+1));
	y_bright = Array.concat(y_bright, getPixel(xi, yi+2));
	y_center = SNR_gaussian_search(y_bright, cardinal, 1);
	
	/*while (abs(x_center) >= 0.5 || abs(y_center) >= 0.5) {
		x_bright = newArray();
		y_bright = newArray();
		if (abs(y_center) >= 0.5) {
			xi += y_center;
			x_bright = getPixel(xi-2, yi);
			x_bright = Array.concat(x_bright, getPixel(xi-1, yi));
			x_bright = Array.concat(x_bright, getPixel(xi, yi));
			x_bright = Array.concat(x_bright, getPixel(xi+1, yi));
			x_bright = Array.concat(x_bright, getPixel(xi+2, yi));
			x_center = SNR_gaussian_search(x_bright, cardinal, 0);
			}
		if (abs(x_center) >= 0.5) {
			yi += x_center;
			y_bright = getPixel(xi, yi-2);
			y_bright = Array.concat(y_bright, getPixel(xi, yi-1));
			y_bright = Array.concat(y_bright, getPixel(xi, yi));
			y_bright = Array.concat(y_bright, getPixel(xi, yi+1));
			y_bright = Array.concat(y_bright, getPixel(xi, yi+2));
			y_center = SNR_gaussian_search(y_bright, cardinal, 1);
			}
		}*/
	//print("Y: " + Fit.p(3));//Debug
	//print("Offsets: " + x_center + ", " + y_center);
	//print(cardinal[0] + ", " + cardinal[1] + ", " + cardinal[2] + ", " + cardinal[3]);

	/*selectImage(window_MaxIP);
	makeOval(xi - cardinal[3], yi - cardinal[0], cardinal[1] + cardinal[3], cardinal[0] + cardinal[2]);
	setBatchMode('show');
	waitForUser("test");
	setBatchMode('hide');*/
	
	//Prevent offset in signal mask
	xi++;
	yi++;
	
	if (cap == 0 || count_bad == true) {
		selectImage(window);
		fillOval(xi - cardinal[3], yi - cardinal[0], cardinal[1] + cardinal[3], cardinal[0] + cardinal[2]);
		return cardinal;
		}
	else {
		spot_count --;
		filtered_spots ++;
		return cardinal;
		}
	}

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
	slope_second = newArray();
	do { //Loop until the slope of the count levels out
		//Get the next Spot Count
		roiManager("Select", 0);
		run("Find Maxima...", "noise=" + maxima + " output=Count");
		setResult("Maxima", nResults - 1, maxima);
		updateResults();
		
		//Add slopes to slope array
		slope = Array.concat(slope, getResult("Count", nResults - 1) - getResult("Count", nResults - 2));
		if (slope.length >= 13) slope = Array.slice(slope, 1, 13);
		maxima += 5;
		
		
		slope_second = Array.concat(slope_second, pow(slope[slope.length-2] - slope[slope.length-1], 2)); //Add new second slope value
		if (slope_second.length == 15) slope_second = Array.slice(slope_second, 1, slope_second.length); //
		
		//Weighted average of second slope
		temp = 0;
		for (n = 0; n < slope_second.length; n ++) {
			slope_second_avg += slope_second[n] * (n + 1);
			temp += n + 1;
			}
		slope_second_avg = slope_second_avg / temp;
		
		//Array.getStatistics(slope_second, dummy, dummy, slope_second_avg, dummy); //Get the average of slope_second
		//Debug
		//print("\nSlope");
		//Array.print(slope);
		//print("Slope_Second");
		//Array.print(slope_second);
		//print("slope_second_avg: " + slope_second_avg);
		} while (slope_second_avg > pow(tolerance_maxima, 2))  //Keep going as long as the average second_slope is greater than 4 (default)
	maxima -= slope.length * 3.535; //Once the condition has been met drop maxima back 70.7%
	updateResults();
	
	
	if (plot == true) { //Create plots for maxima results
		for (n = maxima + slope.length * 3.535; n < maxima + maxima - maxima_start + 10; n += 5) { //Continue measuring spots
			roiManager("Select", 0);
			run("Find Maxima...", "noise=" + n + " output=Count");
			setResult("Maxima", nResults - 1, n);
			updateResults();
			}
		
		start = nResults / 2 - 9;
		if (start < 0) start = 0;
		stop = nResults / 2 + 10;
		if (stop > nResults) stop = nResults;
		xvalues = newArray();
		yvalues = newArray();
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
	if (rsquare == true) {
		for (n = maxima + slope.length * 3.535; n < maxima + maxima - maxima_start + 10; n += 5) { //Continue measuring spots
			roiManager("Select", 0);
			run("Find Maxima...", "noise=" + n + " output=Count");
			setResult("Maxima", nResults - 1, n);
			updateResults();
			}
		if (tolerance_maxima > 9) tolerance_maxima = 0.99;
		else tolerance_maxima = 0.9 + (tolerance_maxima/100); //0.95 default
		xvalues = newArray();
		yvalues = newArray();
		for (n = 0; n < nResults - 1; n++) { //Add all Maxima and Count values to an array
			xvalues = Array.concat(xvalues, getResult("Maxima", n));
			yvalues = Array.concat(yvalues, getResult("Count", n));
			}
		
		segments = SNR_linearize(xvalues, yvalues); //get locations of segment dividers
		//print("Segment Locations:");
		//Array.print(segments);
		segments_lengths = SNR_length(segments); //Get array of segment lengths
		//print("Segment Lengths:");
		//Array.print(segments_lengths);
		Array.getStatistics(segments_lengths, dumb, max, dumb, dumb);
		n = 0;
		while (segments_lengths[n] != max) n++; //Find the array value that matches the largest segment
		maxima = xvalues[segments[n]] + 5;
		return maxima;
		}
	return maxima;
	}
	
function SNR_linearize(xvalues, yvalues) { //Returns an array with locations of segments with > 0.95 rsquared values fitting a linear regression formula
	segments = newArray(0, 0); //Initialize array
	p = 2;
	while (segments[segments.length - 1] < xvalues.length) { //Keep going until you hit the end
		//print("Testing " + segments[segments.length - 1] + " to " + p); //Debug
		do { //From the last entry until the rsquared value drops below the tolerance
			temp_x = Array.slice(xvalues, segments[segments.length - 1], p);
			temp_y = Array.slice(yvalues, segments[segments.length - 1], p);
			Fit.doFit(0, temp_x, temp_y);
			p += 1;
			} while (Fit.rSquared > tolerance_maxima && p < xvalues.length - 1);
		//Fit.plot;
		//setBatchMode('show'); //Debug
		segments = Array.concat(segments, p-2);
		p = segments[segments.length - 1] + 2;
		}
	//Array.print(segments);
	//exit(); //Debug
	segments = Array.slice(segments, 1, segments.length - 1);
	return segments;
	}

function SNR_length(segments) { //Returns an array with the lengths of the given segment array
	segment_len = newArray();
	for (n = 0; n < segments.length - 1; n++) {
		segment_len = Array.concat(segment_len, segments[n+1] - segments[n]);
		}
	return segment_len;
	}

function SNR_results() { //String Manipulation and Saves results to tables
	//Calculate signal to noise ratio and other values
	signoimean = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	sigrel = getResult("Median", nResults - 3) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	signoimedian = sigrel / noirel; //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	cv = getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3); //Coefficient of Variation - Signal
	score = signoimedian * (sigrel-noirel)/100;
	
	//Set results
	for (m = 1; m <= 3; m++) { //Calculate CV for each selection
		setResult("Coefficient of Variation", nResults - m, getResult("StdDev", nResults - m) / getResult("Mean", nResults - m));
		}
	setResult("Score", nResults - 3, score);
	setResult("Mean SNR", nResults - 3, signoimean);
	setResult("Median SNR", nResults - 3, signoimedian);
	setResult("Signal", nResults - 3, sigrel);
	setResult("Noise", nResults - 3, noirel);
	setResult("Spots", nResults - 3, spot_count);
	setResult("Filtered Spots", nResults - 3, filtered_spots);
	setResult("Maxima", nResults - 3, maxima);
	if (expansion_method == "Force Polygon") setResult("Expansion Method", nResults - 3, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots < 5000) setResult("Expansion Method", nResults - 3, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots > 5000) setResult("Expansion Method", nResults - 3, "Ellipse");
	if (expansion_method == "Gaussian") setResult("Expansion Method", nResults - 3, "Gaussian");
	
	//Set Warnings
	/*Warning Codes
	1 = Low spot count (Suspicious)
	2 = Starting Maxima is too high
	4 = Lots of filtered spots
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
	if (getResult("Filtered Spots", nResults - 3) > warning_badspot) warnings += 4;
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
	setResult("Score", nResults - 1, score);
	setResult("Mean SNR", nResults - 1, signoimean);
	setResult("Median SNR", nResults - 1, signoimedian);
	setResult("Signal", nResults - 1, sigrel);
	setResult("Noise", nResults - 1, noirel);
	setResult("Spots", nResults - 1, spot_count);
	setResult("Filtered Spots", nResults - 1, filtered_spots);
	setResult("Maxima", nResults - 1, maxima);
	if (expansion_method == "Force Polygon") setResult("Expansion Method", nResults - 1, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots < 5000) setResult("Expansion Method", nResults - 1, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots > 5000) setResult("Expansion Method", nResults - 1, "Ellipse");
	if (expansion_method == "Gaussian") setResult("Expansion Method", nResults - 1, "Gaussian");
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 1, warnings);
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	return newArray(signoimedian, sigrel, noirel);
	}

function SNR_bright_results() { //String Manipulation and Saves results to tables for bright spots
	//REGULAR SPOTS
	//Calculate signal to noise ratio and other values
	signoimean = (getResult("Mean", nResults - 4) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	sigrel = getResult("Median", nResults - 4) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	signoimedian = sigrel / noirel; //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	cv = getResult("StdDev", nResults - 4) / getResult("Mean", nResults - 4); //Coefficient of Variation - Signal
	score = signoimedian * (sigrel-noirel)/100;
	
	//BRIGHT SPOTS
	signoimean_bright = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	sigrel_bright = getResult("Median", nResults - 3) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel_bright = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	signoimedian_bright = sigrel_bright / noirel_bright; //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	score_bright = signoimedian_bright * (sigrel_bright-noirel_bright)/100;
	
	//Set results

	setResult("Coefficient of Variation", nResults - 1, getResult("StdDev", nResults - 1) / getResult("Mean", nResults - 1)); //Background CV
	setResult("Coefficient of Variation", nResults - 2, getResult("StdDev", nResults - 2) / getResult("Mean", nResults - 2)); //Noise CV
	setResult("Coefficient of Variation", nResults - 3, getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3)); //Bright Signal CV
	setResult("Coefficient of Variation", nResults - 4, getResult("StdDev", nResults - 4) / getResult("Mean", nResults - 4)); //Regular Signal CV
	setResult("Score", nResults - 4, score);
	setResult("Score", nResults - 3, score_bright);
	setResult("Mean SNR", nResults - 4, signoimean);
	setResult("Mean SNR", nResults - 3, signoimean_bright);
	setResult("Median SNR", nResults - 4, signoimedian);
	setResult("Median SNR", nResults - 3, signoimedian_bright);
	setResult("Signal", nResults - 4, sigrel);
	setResult("Signal", nResults - 3, sigrel_bright);
	setResult("Noise", nResults - 4, noirel);
	setResult("Spots", nResults - 4, spot_count);
	setResult("Filtered Spots", nResults - 4, filtered_spots);
	setResult("Maxima", nResults - 4, maxima);
	if (expansion_method == "Force Polygon") setResult("Expansion Method", nResults - 4, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots < 5000) setResult("Expansion Method", nResults - 4, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots > 5000) setResult("Expansion Method", nResults - 4, "Ellipse");
	if (expansion_method == "Gaussian") setResult("Expansion Method", nResults - 4, "Gaussian");
	
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
	if (getResult("Filtered Spots", nResults - 4) > warning_badspot) warnings += 4;
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
	setResult("Score", nResults - 1, score);
	setResult("Bright Score", nResults - 1, score_bright);
	setResult("Mean SNR", nResults - 1, signoimean);
	setResult("Median SNR", nResults - 1, signoimedian);
	setResult("Bright Median SNR", nResults - 1, signoimedian_bright);
	setResult("Signal", nResults - 1, sigrel);
	setResult("Bright Signal", nResults - 1, sigrel_bright);
	setResult("Noise", nResults - 1, noirel);
	setResult("Spots", nResults - 1, spot_count);
	setResult("Filtered Spots", nResults - 1, filtered_spots);
	setResult("Maxima", nResults - 1, maxima);
	if (expansion_method == "Force Polygon") setResult("Expansion Method", nResults - 1, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots < 5000) setResult("Expansion Method", nResults - 1, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots > 5000) setResult("Expansion Method", nResults - 1, "Ellipse");
	if (expansion_method == "Gaussian") setResult("Expansion Method", nResults - 1, "Gaussian");
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 1, warnings);
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	return newArray(signoimedian, sigrel, noirel, signoimedian_bright, sigrel_bright);
	}

function SNR_bright_results_null() { //String Manipulation and Saves results to tables when no bright spots are found
	//REGULAR SPOTS
	//Calculate signal to noise ratio and other values
	signoimean = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	sigrel = getResult("Median", nResults - 3) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	signoimedian = sigrel / noirel; //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	cv = getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3); //Coefficient of Variation - Signal
	score = signoimedian * (sigrel-noirel)/100;
	
	//BRIGHT SPOTS
	signoimedian_bright = 0;
	sigrel_bright = 0;
	noirel_bright = 0;
	score_bright = 0;
	
	//Set results

	setResult("Coefficient of Variation", nResults - 1, getResult("StdDev", nResults - 1) / getResult("Mean", nResults - 1)); //Background CV
	setResult("Coefficient of Variation", nResults - 2, getResult("StdDev", nResults - 2) / getResult("Mean", nResults - 2)); //Noise CV
	setResult("Coefficient of Variation", nResults - 3, getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3)); //Regular Signal CV
	setResult("Score", nResults - 3, score);
	setResult("Mean SNR", nResults - 3, signoimean);
	setResult("Median SNR", nResults - 3, signoimedian);
	setResult("Signal", nResults - 3, sigrel);
	setResult("Noise", nResults - 3, noirel);
	setResult("Spots", nResults - 3, spot_count);
	setResult("Filtered Spots", nResults - 3, filtered_spots);
	setResult("Maxima", nResults - 3, maxima);
	if (expansion_method == "Force Polygon") setResult("Expansion Method", nResults - 3, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots < 5000) setResult("Expansion Method", nResults - 3, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots > 5000) setResult("Expansion Method", nResults - 3, "Ellipse");
	if (expansion_method == "Gaussian") setResult("Expansion Method", nResults - 3, "Gaussian");
	
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
	if (getResult("Filtered Spots", nResults - 3) > warning_badspot) warnings += 4;
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
	setResult("Score", nResults - 1, score);
	setResult("Bright Score", nResults - 1, score_bright);
	setResult("Mean SNR", nResults - 1, signoimean);
	setResult("Median SNR", nResults - 1, signoimedian);
	setResult("Bright Median SNR", nResults - 1, signoimedian_bright);
	setResult("Signal", nResults - 1, sigrel);
	setResult("Bright Signal", nResults - 1, sigrel_bright);
	setResult("Noise", nResults - 1, noirel);
	setResult("Spots", nResults - 1, spot_count);
	setResult("Filtered Spots", nResults - 1, filtered_spots);
	setResult("Maxima", nResults - 1, maxima);
	if (expansion_method == "Force Polygon") setResult("Expansion Method", nResults - 1, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots < 5000) setResult("Expansion Method", nResults - 1, "Polygon");
	if (expansion_method == "Normal" && spot_count + filtered_spots > 5000) setResult("Expansion Method", nResults - 1, "Ellipse");
	if (expansion_method == "Gaussian") setResult("Expansion Method", nResults - 1, "Gaussian");
	if (warnings > 0 && warning_disable == false) setResult("Warning Code", nResults - 1, warnings);
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	return newArray(signoimedian, sigrel, noirel, signoimedian_bright, sigrel_bright);
	}

function SNR_timediff(start, end) { //Returns an array containing the difference between the start and end times in (days, hours, minutes)
	time = newArray(0, 0, 0);
	seconds = abs(round((end - start) / 1000));
	if (seconds >= 60) { //If longer than a minute
		if (seconds/60 >= 60) { //If longer than an hour
			if (seconds/3600 >= 24) { //If longer than a day
				time = newArray(floor(seconds/86400), floor(seconds%86400/3600), round(seconds%3600/60));
				}
			else time = newArray(0, floor(seconds/3600), round(seconds%3600/60)); //Hours and minutes
			}
		else time = newArray(0, 0, round(seconds/60)); //Just minutes
		}
	//Return (0, 0, 0) if less than a minute
	return time;
	}

function SNR_natural_time(prefix, time) { //Accepts a prefix and a time array of (days, hours, minutes)
	temp = prefix;
	and = false;
	if (time[0] == 0 && time[1] == 0 && time[2] == 0) return prefix + " <1 minute"; //Easy case
	if (time[0] > 0) { //If days
		if (time[0] == 1) temp += "1 day ";
		else temp += toString(time[0]) + " days ";
		and = true;
		}
	if (time[0] > 0 && time[1] > 0 && time[2] == 0) temp += "and "; //If only days and hours
	if (time[1] > 0) { //If hours
		if (time[1] == 1) temp += "1 hour ";
		else temp += toString(time[1]) + " hours ";
		and = true;
		}
	if ((time[0] > 0 || time[1] > 0) && time[2] > 0) temp += "and "; //If days or hours and minutes 
	if (time[2] > 0) {
		temp += toString(time[2]) + " minute";
		if (time[2] > 1) temp += "s";
		}
	return temp;
	}
