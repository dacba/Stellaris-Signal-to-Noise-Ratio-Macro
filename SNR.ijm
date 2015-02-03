macro "Calculate Signal to Noise Ratio v0.1...[c]" {
/*
2015-1-30
Version 0.1 - for in-house use only, do not distribute

This macro opens a directory and does an in analysis of spots
Based off of "TrevorsMeasure" or "Measure Dots..."
Uses Find Maxima to find spots and expand the points to a selection used for spot analysis
Use the Default threshold to determine cell noise and background values

Tested on ImageJ version 1.490
Works on 1.49m and 1.49o
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
	Dialog.create("Uncompatible ImageJ Version");
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
tolerance_maxima = 5;
sum_intensity = true;
peak_intensity = false;
plot = false;
count_bad = false;
//Advanced Options
advanced = false;
output = "Out-SNRatio";
objective = 60;

//Dialog
Dialog.create("Spot Processor");

Dialog.addMessage("Please enter the Bounding Stringency, Upward Stringency and Maxima Tolerance");
Dialog.addSlider("Bounding Stringency(Higher = smaller spots):", 0.01, 0.5, tolerance_bounding);
Dialog.addSlider("Upward Stringency(Higher = smaller spots):", 0, 1, tolerance_upward);
Dialog.addSlider("Starting Maxima(Higher = faster):", 0, 200, maxima);
Dialog.addSlider("Maxima Tolerance(Higher = More Spots):", 1, 50, tolerance_maxima);
Dialog.addCheckboxGroup(2, 3, newArray("Polygon Bounding", "Sum Intensity", "Peak Intensity", "Plot Maxima Results", "Include Large Spots", "Advanced Options"), newArray(poly, sum_intensity, peak_intensity, plot, count_bad, advanced));
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
count_bad = Dialog.getCheckbox();
advanced = Dialog.getCheckbox();
maxima_start = maxima;
tolerance_drop = (tolerance_bounding / 5) + 0.89;

if (poly == false) {
	Dialog.create("Warning");
	Dialog.addMessage("The Ellipse function is running an older algorithm for bounding.");
	Dialog.addMessage("If you wish to continue using the Ellipse function instead of the Polygon function, please reduce the Bounding Stringency to 0.1 instead 0.25.");
	Dialog.show();	
	}

//Warn if Choices are outside of recommended range
if (tolerance_bounding > 0.3 || tolerance_bounding < 0.2 || tolerance_upward < 0.5 || tolerance_maxima > 20 || tolerance_maxima < 3 || maxima > 50) {
	Dialog.create("Warning");
	Dialog.addMessage("One or more of your variables are outside of the recommended ranges.\nPlease refer to the recommended ranges below.");
	Dialog.addMessage("Bounding Stringency: 0.2 - 0.3  (" + tolerance_bounding + ")\nUpward Stringency: 0.5 - 1.0  (" + tolerance_upward + ")\nStarting Maxima: 0 - 50  (" + maxima + ")\nMaxima Stringency: 3 - 10  (" + tolerance_maxima + ")");
	Dialog.addMessage("If you would like to continue using these variables press \"OK\" to continue\nBe sure to check the merged tif files and warning codes in the results file to ensure the analysis was done correctly");
	Dialog.show();
	}

if (advanced == true) { //Advanced Options Dialog
	waitForUser("Advanced Options\n\nSome advanced options will break the macro\nOnly change settings if you know what you're doing");
	
	Dialog.create("Advanced Options (Placeholder options only)");
	Dialog.addString("Output Folder Name:", output);
	Dialog.addChoice("Objective Magnification", newArray(60, 100));
	Dialog.show();
	
	output = Dialog.getString();
	objective = Dialog.getChoice();
	objective /= 60;
	objective = 1 / objective;
	}

//Open Tables
run("Table...", "name=SNR width=400 height=200");
if (peak_intensity == true) run("Table...", "name=Peak width=400 height=200");
if (sum_intensity == true) run("Table...", "name=Sum width=400 height=200");
run("Table...", "name=Condense width=400 height=200");

//Initialize SNR table
if (poly == false ) print("[SNR]", "Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Ellipse");
else print("[SNR]", "Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Polygon");
print("[SNR]", "Area, Mean, StdDev, Min, Max, Median, File, Description, Coefficient of Variation, Mean StN Ratio, Median StN Ratio, Median Signal - Background, Median Noise - Background, Spots, Bad Spots, Maxima, Warning Code");

//Initialize Condensed Table
if (poly == false ) print("[Condense]", "Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Ellipse");
else print("[Condense]", "Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " Polygon");
print("[Condense]", "File, Coefficient of Variation, Mean StN Ratio, Median StN Ratio, Median Signal - Background, Median Noise - Background, Spots, Bad Spots, Maxima, Warning Code");

//Initialize Peak and Sum intensity tables if option was chosen
if (peak_intensity == true) print("[Peak]", "Peak Brightness");
if (sum_intensity == true) print("[Sum]", "Sum Intensity");

//Create Directories
dir = getDirectory("Choose Directory containing .nd2 files"); //get directory
outDir = dir + "Out-SNRatio\\";
File.makeDirectory(outDir); //Create new out directory
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
else { //Save as Measurement csv file if running 1.49m
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
		if (endsWith(list[i], "/") && indexOf(path, "Out") == -1) {
			File.makeDirectory(outDir + path); //Recreate file system in output folder
			SNR_main(dir, path); //Recursive Step
			}
		else if (endsWith(list[i], ".nd2")) {
			strip = substring(list[i], 0, indexOf(list[i], ".nd2"));
			stripath = replace(substring(path, 0, indexOf(path, ".nd2")), "/", "_");
			run("Bio-Formats Importer", "open=[" + dir + path + "] autoscale color_mode=Grayscale view=Hyperstack");
			info = getImageInfo();
			if (indexOf(substring(info, indexOf(info, "Negate") - 6, indexOf(info, "Negate")), "DAPI") > -1) close(); //Close if it's the DAPI channel
			else {
			//Initialize Image
			print("File: " + path);
			height = getHeight();
			width = getWidth();
			window_raw = getImageID();
			if (nSlices > 1) { 
				run("Z Project...", "projection=[Max Intensity]"); //Max intensity merge
				window_zstack = getImageID();
				selectImage(window_raw);
				run("Close");
				}
			else window_zstack = window_raw;
			warnings = 0;
			
			//Get Median Background Level
			SNR_background();
			back_median = getResult("Median", nResults - 1);
			run("Clear Results");
			
			//Determine Maxima
			selectImage(window_zstack);
			maxima = SNR_maximasearch();
			run("Clear Results");
			
			//Run peak intensity and Sum intensity measurments
			if (peak_intensity == true) {
				run("Find Maxima...", "noise=" + maxima + " output=[Point Selection]");
				run("Measure");
				String.resetBuffer;
				String.append(path + ", ");
				for (n = 1; n < nResults; n++) String.append(getResult("Mean", n) + ", ");
				print("[Peak]", String.buffer);
				run("Find Maxima...", "noise=" + maxima + " output=List");
				}
			if (sum_intensity == true) {
				run("Find Maxima...", "noise=" + maxima + " output=List");
				setResult("Sum Intensity", 0, 0);
				for (q = 0; q < nResults; q++) {
					selectImage(window_zstack);
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
			//Expand dots
			if (poly == false) { //Run the faster dots program
				for (q = 0; q < nResults && q < 2500; q++) {
					SNR_dots(round(getResult("X", q)), round(getResult("Y", q))); //Run dots with different x and y values
					}//End of dots loop
				}
			else { //Run the slower polygon program
				for (q = 0; q < nResults && q < 2500; q++) {
					SNR_polygon(round(getResult("X", q)), round(getResult("Y", q))); //Run dots with different x and y values
					}//End of dots loop
				}
			
			//Create Selection of signal
			print(nResults + " points processed");
			print(bad_spots + " bad points detected");
			selectImage(window_signal);
			run("Create Selection");
			roiManager("Add"); //Create Signal selection
			run("Make Inverse"); //Make selection inverted
			roiManager("Add"); //Create Inverse Signal selection
			
			selectImage(window_signal);
			close();
			
			//Run signal
			selectImage(window_zstack);
			SNR_signal();
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Signal");
			updateResults();
			
			//Run Noise
			selectImage(window_zstack);
			SNR_noise(); 
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Cell Noise");
			updateResults();
			
			//Run Background
			selectImage(window_zstack);
			SNR_background();
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Background");
			updateResults();
			
			//Results
			signoimedian = SNR_results();
			
			//Save Images
			selectImage(window_zstack);
			run("Select None");
			setThreshold(0, 10000);
			run("Create Selection");
			resetThreshold();
			run("Enhance Contrast", "saturated=0.01"); //Make the MaxIP image pretty
			run("Select None");
			run("8-bit");
			drawString(path +"\nSNR: " + signoimedian, 10, 40, 'white');
			//Add Slice with Cell Noise and Signal areas on it
			run("Add Slice");
			roiManager("Select", newArray(1,2));
			roiManager("AND");
			setColor(128);
			fill();
			run("Select None");
			roiManager("Select", 0);
			setColor(255);
			fill();
			drawString("Maxima: " + maxima + "\nSpots: " + spot_count + "/" + bad_spots, 10, 40, 'white');
			run("Select None");
			saveAs("tif", outDir + sub + strip + "_Merge.tif");
			
			run("Close All");
			roiManager("Deselect");
			roiManager("Delete");
			}} //end of else
		}//end of for loop
	}//end of function

function SNR_background() { //Measures background, the darkest part, where there are no cells
	run("Select None");
	setAutoThreshold("Default"); //Default is good for background (especially very dark cell noise)
	run("Create Selection");
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results
	} //End of Function

function SNR_noise() { //Measures Cell Noise, ensure dots and inverse dots are in the ROI manager, positions 0 and 1 respectively
	run("Select None");
	setAutoThreshold("Default dark"); //Threshold cell noise
	run("Create Selection"); //Create selection 2
	run("Enlarge...", "enlarge=-1 pixel"); //Remove very small selections
	run("Enlarge...", "enlarge=11 pixel"); //Expand Cell noise boundary; Needed for exceptional images
	roiManager("Add");
	roiManager("Select", newArray(1,2));//Select Inverse dots and Cell Noise
	roiManager("AND"); //Select regions of Cell Noise and inverse of dots
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results and clear ROI manager
	}//End of Noise function

function SNR_signal() { //Measures Signal, ensure dots is in ROI manager, position 0
	run("Select None");
	roiManager("Select", 0);
	run("Measure");
	run("Select None");
	} //End of signal function

function SNR_dots(xi, yi) { //Searches N, S, E, W and then draws an ellipse on mask image
	selectImage(window_zstack);
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

function SNR_polygon(xi, yi) { //Searches in eight cardinal directions and draws polygon on mask image
	selectImage(window_zstack);
	bright = getPixel(xi,yi) - back_median; //Get Relative brightness of brightest pixel
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
		for (p = 0; p < pixel_dif.length; p++) {
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //if the difference is negative, make it positive
			else pixel_dif[p] = pixel_dif[p] / tolerance_upward; //if the difference is positive, divide by upward tolerance
			}
		if (pixel_dif.length >= 1) {
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		//print(pixel.length, pixel_avg);
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r-=pixel.length;
		else r-=2;
		}
	north = yi + r; 
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
	northeast = r; 
	if (r >= 5) cap ++;
	
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
	east = xi + r; //East point
	if (r >= 5) cap ++;
	
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
	southeast = r; //Southeast point
	if (r >= 5) cap ++;
	
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
	south = yi - r; //South Point
	if (r >= 5) cap ++;
	
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
	southwest = r; //Southwest point
	if (r >= 5) cap ++;
	
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
	west = xi - r; //West point
	if (r >= 5) cap ++;
	
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
	northwest = r; //Northwest point
	if (r >= 5) cap ++;
	  
	if (cap <= 3 || count_bad == true) {
		selectImage(window_signal);
		makePolygon(xi, north, xi + northeast, yi + northeast, east, yi, xi + southeast, yi - southeast, 	xi, south, xi - southwest, yi - southwest, west, yi, xi - northwest, yi + northwest);
		//exit();
		fill();
		}
	else {
		spot_count --;
		bad_spots ++;
		}
	}//End of crazy polygon function
	
function SNR_maximasearch() { //Searches upwards until spot count levels out
	maxima = maxima_start;
	slope = newArray();
	slope_second = newArray();
	slope_second_avg = 1;
	run("Clear Results");
	//Initialize Maxima Results
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	maxima += 5;
	
	//Second run
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	maxima += 5;
	
	//Get first slope value
	slope = (getResult("Count", nResults - 1) - getResult("Count", nResults - 2));
	updateResults();
	do { //Loop until the slope of the count levels out
		//Get the next Spot Count
		run("Find Maxima...", "noise=" + maxima + " output=Count");
		setResult("Maxima", nResults - 1, maxima);
		updateResults();
		
		//Add slopes to slope array
		slope = Array.concat(slope, getResult("Count", nResults - 1) - getResult("Count", nResults - 2));
		if (slope.length >= 6) slope = Array.slice(slope, 1, 6);
		maxima += 5;
		
		//Add second degree slopes to slope_second array
		slope_second = newArray();
		for (i = 1; i < slope.length; i++) slope_second = Array.concat(slope_second, slope[i-1] - slope[i]);
		if (slope_second.length >= 5) slope_second = Array.slice(slope_second, 1, 5);
		
		Array.getStatistics(slope_second, dummy, dummy, slope_second_avg, dummy); //Get the average of slope_second
		//Debug
		//print("\nSlope");
		//Array.print(slope);
		//print("Slope_Second");
		//Array.print(slope_second);
		//print("slope__second_avg\n" + slope_second_avg);
		} while (slope_second_avg < - tolerance_maxima / 10)  //Keep going as long as the average second_slope is less than -10 (default)
	maxima -= slope.length * 2.5; //Once the condition has been met drop maxima back half the number of steps to make it the middle of the 
	updateResults();
	
	if (plot == true) { //Create plots for maxima results
		lowest_count = getResult("Count", nResults - 1); //Define the lowest Y value
		for (n = maxima; n < maxima + maxima - maxima_start + 10; n += 5) { //Continue measuring spots
			run("Find Maxima...", "noise=" + n + " output=Count");
			setResult("Maxima", nResults - 1, n);
			updateResults(); //Not Required
			}
		for (n = 0; n < nResults; n++) { //Add Maxima and Count values to an array
			xvalues = Array.concat(xvalues, getResult("Maxima", n));
			yvalues = Array.concat(yvalues, getResult("Count", n));
			}
		xvalues = Array.slice(xvalues, 1, n); //Remove first x value
		yvalues = Array.slice(yvalues, 1, n); //Remove first y value
		Plot.create("Plot", "Maxima", "Count", xvalues, yvalues); //Make plot
		Plot.drawLine(maxima, yvalues[n-2], maxima, yvalues[0]); //Draw vertical line at maxima
		Plot.drawLine(maxima_start, lowest_count, maxima, lowest_count); //Draw horizontal line from y axis to maxima
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
	signoimean = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1));
	signoimedian = (getResult("Median", nResults - 3) - getResult("Median", nResults - 1)) / (getResult("Median", nResults - 2) - getResult("Median", nResults - 1));
	sigrel = getResult("Median", nResults - 3) - getResult("Median", nResults - 1);
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1);
	cv = getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3); //Coefficient of Variation - Signal
	
	//Set results
	for (m = 1; m <= 3; m++) { //Calculate CV for each selection
		setResult("Coefficient of Variation", nResults - m, getResult("StdDev", nResults - m) / getResult("Mean", nResults - m));
		}
	setResult("Mean StN Ratio", nResults - 3, signoimean);
	setResult("Median StN Ratio", nResults - 3, signoimedian);
	setResult("Median Signal - Background", nResults - 3, sigrel);
	setResult("Median Noise - Background", nResults - 3, noirel);
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
	for (m = 1; m <= 2; m++) { //If the Coefficient of Variation for Noise or Background is greater than 0.15 then warn user
		if (getResult("Coefficient of Variation", nResults - m) > 0.15) setResult("Warning Code", nResults - m, 8);
		}
	if (getResult("Mean", nResults - 3) / getResult("StdDev", nResults - 3) > 0.2) warnings += 8;
	if (getResult("Spots", nResults - 3) < 100) warnings += 1;
	if (getResult("Bad Spots", nResults - 3) > 20) warnings += 4;
	if (maxima_start == maxima) warnings += 2;
	if (warnings > 0) setResult("Warning Code", nResults - 3, warnings);
	if ((getResult("Warning Code", nResults - 1) == 8 || getResult("Warning Code", nResults - 2) == 8) && getResult("StdDev", nResults - 3) / getResult("Mean", nResults - 3) <= 0.15) warnings += 8; //If the Noise or background has a bad cv and the signal didn't, warn in condensed file
	updateResults();
	
	//String manipulation and saving to SNR table
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[SNR]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	//Save Condensed Results
	setResult("File", nResults, path);
	setResult("Signal Coefficient of Varation", nResults - 1, cv);
	setResult("Mean StN Ratio", nResults - 1, signoimean);
	setResult("Median StN Ratio", nResults - 1, signoimedian);
	setResult("Median Signal - Background", nResults - 1, sigrel);
	setResult("Median Noise - Background", nResults - 1, noirel);
	setResult("Spots", nResults - 1, spot_count);
	setResult("Bad Spots", nResults - 1, bad_spots);
	setResult("Maxima", nResults - 1, maxima);
	if (warnings > 0) setResult("Warning Code", nResults - 1, warnings);
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	return signoimedian;
	}

print("-- Done --");
showStatus("Finished.");
}//end of macro