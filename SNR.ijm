
macro "Calculate Signal to Noise Ratio Beta...[c]" {
version = "1.1"; //Beta Version

/*
Latest Version Date: 2015-10-9
Written by Trevor Okamoto, Research Associate, Stellaris R&D. Biosearch Technologies Inc.

ImageJ/Fiji Macro for analyzing single molecule RNA FISH images from a Nikon Eclipse
Separates the Signal from the surrounding cellular noise, and the background from the cellular noise.  These segments are measured for their mean and median brightness values.  These values are used to calculate the relative signal and noise, and from that the signal to noise ratio.  Other options are available such as spot filtering, and tolerance tweaking.
Copyright (C) 2015 Trevor Okamoto, LGC Biosearch Technologies

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

Tested on ImageJ version 1.50c
Not Compatible with 1.49n
*/

//Initialize
setBatchMode(true);
setOption("ShowRowNumbers", false);
requires("1.48v");
run("Set Measurements...", "area mean standard min median redirect=None decimal=3");
run("Input/Output...", "jpeg=85 gif=-1 file=.csv save_column");
setFont("SansSerif", 22);
print("\\Clear");
roiManager("reset");
run("Collect Garbage");
run("Clear Results");
run("Close All");

if (isOpen("SNR")) {
	selectWindow("SNR");
	run("Close");
	}
if (isOpen("Condense")) {
	selectWindow("Condense");
	run("Close");
	}
if (isOpen("Peak")) {
	selectWindow("Peak");
	run("Close");
	}
if (isOpen("Sum")) {
	selectWindow("Sum");
	run("Close");
	}

if (indexOf(getInfo("os.name"), "Windows") == -1) {
	Dialog.create("Potentially Incompatible Operating System");
	Dialog.addMessage("Warning!\nThis macro was developed for Windows.\nThis macro may not work as intended on other operating systems.");
	Dialog.addCheckbox("I want to run this anyway", false);
	Dialog.show();
	temp = Dialog.getCheckbox();
	if (temp == false) exit();
	}


if (indexOf(getVersion(), "1.49n") > -1) {
	Dialog.create("Incompatible ImageJ Version");
	Dialog.addMessage("Warning!\nYou are using ImageJ version 1.49n, which has known issues with this macro.\nA temporary fix has been implemented, however upgrading is strongly recommended\nUpgrade your ImageJ version by going to \"Help\" > \"Update ImageJ\".");
	Dialog.addCheckbox("I want to run this anyway", false);
	Dialog.show();
	temp = Dialog.getCheckbox();
	if (temp == false) exit("Upgrade by going to \"Help\" > \"Update ImageJ\"");
	}


//Default Variables
tif_ready = false; //Determines if pre-saved tif files are available
tolerance_bounding = 0.2; //Tolerance for ellipse bounding. Higher means smaller ellipsis 
tolerance_upward = 0.8; //Tolerates upward movement (0 means any upward movement will be tolerated, 1 means tolerance will be the same as downward movement)
maxima = 20; //Beginning Maxima value
expansion_method = "Normal"; //Expansion Method
normal_limit = 5000; //Will run ellipse when there are more than this number of spots
tolerance_maxima = 8; //Tolerance for maxima
sum_intensity = false; //Check to run sum intensity or not
peak_intensity = false; //Check to run peak intensity
plot = false; //Check to plot find maxima curve
filter = true; //Check to filter spots
user_area = false; //Check for user defined area
user_area_rev = false; //Check if to invert selection
debug_switch = false; //Enables all debug options
custom_lut = false; //Assign lut values to images
ztrim = false; //Trim z-stack

//Advanced Options
advanced = false;
user_area_double_check = true; //Double checks with the user if 
recreate_tif = false; //Forces re-saving tif files
maxima_inc = 20; //Maxima Increment
delay = 0; //Network delay
rsquare = false; //Check for linear fit maxima search
output = "Out-SNRatio"; //Output folder
count_bad = false; //Check to count large spots
output_location = false;
warning_cvspot = 0.5; //Warning cutoff for coefficient of variation signal
warning_cvnoise = 0.25; //Warning cutoff for coefficient of variation noise
warning_spot = 100; //Warning cutoff for spot number
warning_badspot = 0.5; //Warning cutoff for filtered spot number
warning_disable = false; //Disable warnings
exclude = "NULL"; //Will exclude any file or folder containing this string
filter_low = 2; //Defines the number of standard deviation points below the mean to filter signal
filter_high = 5; //Defines the number of standard deviation points above the mean to separate signal
noise_stdev = 3; //Defines the number of standard deviation points above the mean noise value for peak signal to be counted
gauss_offset = 2; //Defines the threshold of standard deviation of the Gaussian fit
gauss_d = 2; //Number of standard deviations to move outward of Gaussian fit
np_radii = 9;

min_fitc = 0;
max_fitc = 0;
min_cy3 = 0;
max_cy3 = 0;
min_cy35 = 0;
max_cy35 = 0;
min_cy55 = 0;
max_cy55 = 0;


area_cutoff = 5.22; //Area (micron^2) the regular selection must be to be counted, specifically 50 bright spots averaging 3x3 pixels
area_cutoff_bright = 5.22; //Area (micron^2) the bright selection must be to be counted



//Dialog
Dialog.create("Spot Processor");

Dialog.addMessage("Please enter the Bounding Stringency, Upward Stringency and Maxima Tolerance");
Dialog.addSlider("Bounding Stringency(Higher = smaller spots):", 0.01, 0.5, tolerance_bounding);
Dialog.addSlider("Upward Stringency(Higher = smaller spots):", 0, 1, tolerance_upward);
Dialog.addSlider("Maxima Tolerance(Higher = More Spots):", 1, 50, tolerance_maxima);
Dialog.addChoice("Signal Masking Option:", newArray("Normal", "Force Polygon", "Gaussian"));
Dialog.addCheckboxGroup(3, 3, newArray("Sum Intensity", "Peak Intensity", "Plot Maxima Results", "User Defined Area", "Signal Filtering", "Advanced Options", "Custom LUT", "Auto Trim Z-stack"), newArray(sum_intensity, peak_intensity, plot, user_area, filter, advanced, custom_lut, ztrim));
Dialog.show();

//Retrieve Choices
tolerance_bounding = Dialog.getNumber();
tolerance_upward = Dialog.getNumber();
tolerance_maxima = Dialog.getNumber();
expansion_method = Dialog.getChoice();
sum_intensity = Dialog.getCheckbox();
peak_intensity = Dialog.getCheckbox();
plot = Dialog.getCheckbox();
user_area = Dialog.getCheckbox();
filter = Dialog.getCheckbox();
advanced = Dialog.getCheckbox();
custom_lut = Dialog.getCheckbox();
ztrim = Dialog.getCheckbox();
maxima_start = maxima;
tolerance_drop = (tolerance_bounding / 5) + 0.89;

//Warn if Choices are outside of recommended range
if (tolerance_bounding > 0.3 || tolerance_bounding < 0.2 || tolerance_upward < 0.4 || tolerance_upward > 0.8|| tolerance_maxima > 15 || tolerance_maxima < 2) {
	Dialog.create("Warning");
	Dialog.addMessage("One or more of your variables are outside of the recommended ranges.\nPlease refer to the recommended ranges below.");
	Dialog.addMessage("Bounding Stringency: 0.2 - 0.3  (" + tolerance_bounding + ")\nUpward Stringency: 0.4 - 0.8  (" + tolerance_upward + ")\nMaxima Stringency: 2 - 10  (" + tolerance_maxima + ")");
	Dialog.addMessage("If you would like to continue using these variables press \"OK\" to continue\nBe sure to check the merged tif files and warning codes in the results file to ensure the analysis was done correctly");
	Dialog.show();
	}

if (custom_lut == true) {
	Dialog.create("Separate LUT");
	
	Dialog.addMessage("Any \"0\" will be replaced by the Auto Enhance Contrast Numbers");
	Dialog.addMessage("\nEx.\nEnter 0 for min and any number to max to let the program pick the min value");
	
	Dialog.addMessage("FITC");
	Dialog.addNumber("min:", 0);
	Dialog.addNumber("max:", 0);
	Dialog.addMessage("Cy3");
	Dialog.addNumber("min:", 0);
	Dialog.addNumber("max:", 0);
	Dialog.addMessage("Cy3.5");
	Dialog.addNumber("min:", 0);
	Dialog.addNumber("max:", 0);
	Dialog.addMessage("Cy5.5");
	Dialog.addNumber("min:", 0);
	Dialog.addNumber("max:", 0);
	
	Dialog.show();
	
	min_fitc = Dialog.getNumber();
	max_fitc = Dialog.getNumber();
	min_cy3 = Dialog.getNumber();
	max_cy3 = Dialog.getNumber();
	min_cy35 = Dialog.getNumber();
	max_cy35 = Dialog.getNumber();
	min_cy55 = Dialog.getNumber();
	max_cy55 = Dialog.getNumber();
	}
	
if (advanced == true) { //Advanced Options Dialog
	//waitForUser("Some advanced options will break the macro\nOnly change settings if you know what you're doing\n\nSome settings have not been fully implemented yet and are placeholders at the moment");
	
	Dialog.create("Advanced Options");
	Dialog.addString("Output Folder Name:", output);
	Dialog.addString("Exclude Files and Folders:", exclude);
	Dialog.addSlider("Starting Maxima:", 0, 200, maxima);
	Dialog.addSlider("Tolerance Drop", 0.5, 1, tolerance_drop);
	Dialog.addSlider("Dim StdDev", 1, 5, filter_low);
	Dialog.addSlider("Bright StdDev", 1, 5, filter_high);
	Dialog.addSlider("Signal/Noise StdDev Separation", 0, 5, noise_stdev);
	Dialog.addSlider("Signal Area Cutoff", 0, 10, area_cutoff);
	Dialog.addSlider("Bright Signal Area Cutoff", 0, 10, area_cutoff_bright);
	Dialog.addSlider("Network Delay", 0, 10, delay);
	Dialog.addCheckboxGroup(3, 3, newArray("Include Large Spots", "Disable Warning Codes", "Linear Fit Maxima Search(Experimental)", "Force Create New Max/Median Images", "User Area Double Check", "Specify Output Folder Location", "Enable Debugging"), newArray(count_bad, warning_disable, rsquare, recreate_tif, user_area_double_check, output_location, debug_switch));
	Dialog.addMessage("Warning Cutoffs");
	Dialog.addSlider("Coefficient of Variation S", 0, 2, warning_cvspot);
	Dialog.addSlider("Coefficient of Variation N", 0, 2, warning_cvnoise);
	Dialog.addSlider("Suspicious Spot Count", 0, 200, warning_spot);
	Dialog.addSlider("Filtered Spot Ratio", 0, 1, warning_badspot);
	Dialog.show();
	
	output = Dialog.getString();
	
	exclude = Dialog.getString();
	maxima = Dialog.getNumber();
	tolerance_drop = Dialog.getNumber();
	filter_low = Dialog.getNumber();
	filter_high = Dialog.getNumber();
	noise_stdev = Dialog.getNumber();
	area_cutoff = Dialog.getNumber();
	area_cutoff_bright = Dialog.getNumber();
	delay = Dialog.getNumber();
	count_bad = Dialog.getCheckbox();
	warning_disable = Dialog.getCheckbox();
	rsquare = Dialog.getCheckbox();
	recreate_tif = Dialog.getCheckbox();
	user_area_double_check = Dialog.getCheckbox();
	output_location = Dialog.getCheckbox();
	debug_switch = Dialog.getCheckbox();
	warning_cvspot = Dialog.getNumber();
	warning_cvnoise = Dialog.getNumber();
	warning_spot = Dialog.getNumber();
	warning_badspot = Dialog.getNumber();
	}

output = output + "Beta_" + version; //Change output folder to include version number

if (rsquare == true && filter == false) filter = getBoolean("Linear Fit Maxima Search works best with \"Signal Filtering\".\nEnable \"Signal Filtering?\""); //Check for filtering and linear fit maxima search

//Open Tables
run("Table...", "name=SNR width=400 height=200");
if (peak_intensity == true) run("Table...", "name=Peak width=40 height=200");
if (sum_intensity == true) run("Table...", "name=Sum width=400 height=200");
run("Table...", "name=Condense width=400 height=200");

//Write table headers
table_head = "Version " + version + " Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " " + expansion_method; //-----Add maxima search method-----
print("[SNR]", table_head);
print("[Condense]", table_head);

//Write Table Labels
table_head = "Area,Mean,StdDev,Min,Max,Median,File,Description,Coefficient of Variation,Signal - Noise,Score,Mean SNR,Median SNR,Signal,Noise,Spots,Filtered Spots,Maxima,Expansion Method";
if (warning_disable == false) table_head += ",Warning Code";
print("[SNR]", table_head);

if (filter == true) table_head = "File,Bright Signal - Noise,Signal - Noise,Score,Bright Score,Mean SNR,Median SNR,Bright Median SNR,Signal,Bright Signal,Noise,Spots,Filtered Spots,Maxima,Expansion Method";
else table_head = "File,Score,Mean SNR,Median SNR,Signal,Noise,Spots,Filtered Spots,Maxima,Expansion Method";
if (warning_disable == false) table_head += ",Warning Code";
print("[Condense]", table_head);


//Initialize Peak and Sum intensity tables
if (peak_intensity == true) print("[Peak]", "Peak Brightness");
if (sum_intensity == true) print("[Sum]", "Sum Intensity");

//Create Directories
output_name = "Results " + expansion_method + " " + tolerance_bounding + "-" + tolerance_upward + "-" + tolerance_maxima;
if (filter == true) output_name += " Filtered-" + filter_low + "-" + filter_high + "-" + noise_stdev;
if (rsquare == true) output_name += " LinMaxSearch";
if (custom_lut == true) output_name += " LUT-";
if (custom_lut == true && min_cy3 !=0 && max_cy3 != 0) output_name = output_name + "Cy3" + min_cy3 + "-" + max_cy3;
if (custom_lut == true && min_cy35 !=0 && max_cy35 != 0) output_name = output_name + "_Cy35" + min_cy35 + "-" + max_cy35;
if (custom_lut == true && min_cy55 !=0 && max_cy55 != 0) output_name = output_name + "_Cy55" + min_cy55 + "-" + max_cy55;
if (custom_lut == true && min_fitc !=0 && max_fitc != 0) output_name = output_name + "_FITC" + min_fitc + "-" + max_fitc;
if (user_area == true) output_name += " Selection-" + toHex(random*random*random*1000) + toHex(random*random*random*1000);

inDir = getDirectory("Choose Directory Containing Image Files"); //Get inDirectory
if (output_location == false) outDir = inDir + output + File.separator; //Create base output inDirectory
else outDir = getDirectory("Choose Directory where the output files should be saved") + output + File.separator;
File.makeDirectory(outDir); //Create base output inDirectory
outDir = outDir + output_name + File.separator;//Create specific output inDirectory
textDir = outDir + "Saved data" + File.separator;
File.makeDirectory(outDir); //Create specific output inDirectory
File.makeDirectory(textDir);
mergeDir = inDir + "Out-Merged Images" + File.separator;
if (plot == true) File.makeDirectory(outDir + "Plots" + File.separator); //Create Plots inDirectory
tif_ready = File.exists(mergeDir + "log.txt");
if (recreate_tif == true) tif_ready = false;
if (tif_ready == false) { //Create Merged images folder if doesn't already exist
	File.makeDirectory(mergeDir);
	File.makeDirectory(mergeDir + "Max" + File.separator);
	File.makeDirectory(mergeDir + "Max 8-bit" + File.separator);
	File.makeDirectory(mergeDir + "Median" + File.separator);
	File.makeDirectory(mergeDir + "Subtract" + File.separator);
	}

//RUN IT!
total_start = getTime();
if (File.exists(mergeDir + "log.txt")) File.append("----------\nStarted " + version + "...\n" + output_name, mergeDir + "log.txt");
final_file_list = "";
final_file_list = SNR_main(inDir, "");

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

if (File.exists(mergeDir + "log.txt") == false) {
	File.saveString(inDir + "\n----------" + final_file_list + "\n", mergeDir + "log.txt");
	File.append("==========\n \nStarted " + version + "...\n" + output_name, mergeDir + "log.txt");
	}

File.delete(inDir + "temp.txt");
File.append("...Completed", mergeDir + "log.txt");
run("Collect Garbage");
print("-- Done --");
showStatus("Finished.");
} //end of macro

function SNR_main(dir, sub) {
	run("Bio-Formats Macro Extensions");
	list = getFileList(dir + sub);//get file list
	final_file_list = "";
	img_files = 0;
	img_processed = 0;
	img_skip = 0;
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], ".nd2") || endsWith(list[i], ".tif") && indexOf(list[i], exclude) == -1) img_files++;
		}
	if (debug_switch) print(img_files); //Debug
	start_time = getTime();
	for (i = 0; i < list.length; i++) { //for each file
		showProgress(1 / list.length - 1);
		path = sub + list[i];
		window_MaxIP = 0;
		window_raw = 0;
		if ((endsWith(list[i], "/") || endsWith(list[i], "\\")) && indexOf(path, output) == -1 && indexOf(path, "Out") == -1 && indexOf(path, exclude) == -1) { //For Folders
			SNR_main(dir, path); //Recursive Step
			}
		else if (endsWith(list[i], "/") == false && endsWith(list[i], "\\") == false && indexOf(list[i], exclude) == -1) { //For valid files
			print("------------\nFile: " + path);
			stripath = replace(substring(path, 0, lastIndexOf(path, ".")), "\\", "_");
			stripath = replace(stripath, "/", "_");
			reduced_cardinal = false;
			//If file already analyzed with the current version and settings, SKIP
			if (File.exists(textDir + stripath + "_Raw.csv") && File.exists(textDir + stripath + "_Condense.csv") && recreate_tif == false) {
				print("File already analyzed with current version and settings... Skipping");
				print("[SNR]", File.openAsString(textDir + stripath + "_Raw.csv"));
				print("[Condense]", File.openAsString(textDir + stripath + "_Condense.csv"));
				}
			//If max median are present, use them instead
			else if (File.exists(mergeDir + "Max" + File.separator + stripath + ".tif") && File.exists(mergeDir + "Median" + File.separator + stripath + ".tif") && recreate_tif == false) { //If tif Files exist
				if (debug_switch) print(dir + list[i]); //Debug
				open(mergeDir + "Max" + File.separator + stripath + ".tif"); //Open Max
				window_MaxIP = getImageID();
				channel = getMetadata("Info");
				height = getHeight();
				width = getWidth();
				open(mergeDir + "Median" + File.separator + stripath + ".tif"); //Open Median
				window_Median = getImageID();
				if (File.exists(mergeDir + "Subtract" + File.separator + stripath + ".tif")) {
					open(mergeDir + "Subtract" + File.separator + stripath + ".tif"); //Open subract background image
					window_Subtract = getImageID();
					}
				else {
					selectImage(window_MaxIP);
					run("Duplicate", " ");
					window_Subtract = getImageID();
					run("Subtract Background...", "rolling=20"); //Subtract Background
					run("Sharpen");
					}
				}
			//For raw files
			else if (endsWith(list[i], ".nd2") || endsWith(list[i], ".tif")) {
				run("Bio-Formats Importer", "open=[" + dir + path + "] display_metadata view=[Metadata only]");
				selectWindow("Original Metadata - " + list[i]);
				saveAs("Text", inDir + "temp.txt");
				run("Close");
				info = File.openAsString(inDir + "temp.txt");
				if (indexOf(info, "Dimensions	XY(") > -1 && indexOf(info, "C=") == -1) { //If multidimension and hasn't been split
					print("Multi-dimension file detected, splitting");
					run("Bio-Formats Importer", "open=[" + dir + path + "] color_mode=Grayscale open_all_series split_channels view=Hyperstack stack_order=XYCZT use_virtual_stack");
					File.makeDirectory(dir + "\\Split Files\\");
					print("Saving Splits");
					do {
						selectImage(1);
						saveAs("tif", dir + "\\Split Files\\" + getTitle() + ".tif");
						close;
						print(nImages + " remaining");
						} while (nImages >= 0);
					//exit("This Macro is only compatible with files that contain a single Z-stack.\nYour file has been split\nPlease restart the program.");
					}
				else { //If not multidimension or has been split assign channel
					if (indexOf(info, "Name	Cy3") > -1 || indexOf(info, "C=3") > -1) channel = "Cy3";						
					else if (indexOf(info, "Name	Cy3.5") > -1 || indexOf(info, "C=2") > -1) channel = "Cy3.5";
					else if (indexOf(info, "Name	Cy5.5") > -1 || indexOf(info, "C=1") > -1) channel = "Cy5.5";
					else if (indexOf(info, "Name	FITC") > -1 || indexOf(info, "C=4") > -1) channel = "FITC";
					else if (indexOf(info, "Name	DAPI") > -1 || indexOf(info, "C=0") > -1) channel = "DAPI";
					if (channel != "DAPI") {
						run("Bio-Formats Importer", "open=[" + dir + path + "] autoscale color_mode=Grayscale split_channels view=Hyperstack stack_order=XYCZT");
						window_raw = getImageID();
						if (nSlices == 1) {
							close();
							window_raw = 0;
							print("Images must have more than one slice");
							img_files--;
							img_skip++;
							}
						}
					else if (channel == "DAPI"){
						print("Skipping DAPI channel");
						img_files--;
						img_skip++;
						window_raw = 0;
						}
					}
				if (window_raw != 0) { //Initialize Image if opened
					height = getHeight();
					width = getWidth();
					z_min = 1;
					z_max = nSlices;
					if (ztrim == true) { //Remove excess slices via find edges
						run("Duplicate...", "duplicate");
						run("Find Edges", "stack");
						edge = newArray();
						for (m = 1; m <= nSlices; m++) {
							setSlice(m);
							run("Measure");
							edge = Array.concat(edge, getResult("Max", nResults - 1));
							}
						run("Clear Results");
						
						//Move inward from bottom edge, trigger at 20% increase from moving average
						edge_avgarr = newArray();
						z_min = 0;
						do {
							edge_avgarr = Array.concat(edge_avgarr, edge[z_min]);
							Array.getStatistics(edge_avgarr, dumb, dumb, edge_avg, dumb);
							z_min++;
							} while (z_min < nSlices && (edge[z_min]/edge_avg < 1.2 || z_min < 3));
						if (z_min > nSlices/2) z_min = 0; //algorithm likely messed up or there is no signal
						
						edge_avgarr = newArray();
						z_max = nSlices - 1;
						do {
							edge_avgarr = Array.concat(edge_avgarr, edge[z_max]);
							Array.getStatistics(edge_avgarr, dumb, dumb, edge_avg, dumb);
							z_max--;
							} while (z_max > 1 && (edge[z_max]/edge_avg < 1.2 || z_max > nSlices - 4));
						if (z_max < nSlices/2) z_max = nSlices; //algorithm likely messed up or there is no signal
						close;
						print("Z Project range: " + z_min + " - " + z_max);
						}
					selectImage(window_raw);
					run("Z Project...", "start=" + z_min + " stop=" + z_max + " projection=[Max Intensity]"); //Max intensity merge
					window_MaxIP = getImageID();
					run("Duplicate...", " ");
					window_Subtract = getImageID();
					run("Subtract Background...", "rolling=20"); //Subtract Background
					run("Sharpen");
					selectImage(window_raw);
					run("Z Project...", "projection=Median"); //Median intensity merge
					window_Median = getImageID();
					run("Gaussian Blur...", "sigma=3"); //Blur Median
					selectImage(window_raw);
					run("Close");
					}
				}
			}
		//Analysis, only if a file was opened
		if (window_MaxIP != 0) {
			img_processed++;
			final_file_list += "\n" + list[i]; //Save file names
			selectImage(window_MaxIP);
			getPixelSize(pixel_unit, pixel_width, pixel_height);
			if (pixel_unit != "pixel") {
				pixel_width *= 9.2764378478664192949907235621521;
				pixel_height *= 9.2764378478664192949907235621521;
				}
			
			//Get User Area Selection, if needed
			if (user_area == true) { //For selecting areas
				selectImage(window_MaxIP);
				run("Enhance Contrast", "saturated=0.01");
				setBatchMode('show');
				user_area_rev = getBoolean("Click \"Yes\" to analyze all but your selection\nPress \"No\" to analyze only your selection\n \Make no selection to analyze the entire image");
				setTool("freehand");
				waitForUser("----------------======WAIT======----------------\n Click \"OK\" AFTER selecting area for analysis\n   Select nothing to analyze the entire image\n----------------======WAIT======----------------");
				setBatchMode('hide');
				if ((selectionType() >= 0 && selectionType() < 4) || selectionType == 9) { //If valid selection selection
					if (user_area_rev == true) run("Make Inverse");
					roiManager("Add");
					}
				else if (selectionType() == -1 && user_area_double_check == true) { //If no selection
					user_area_double_check = false;
					temp = getBoolean("Are you sure you want to analyze the whole image?");
					if (temp == true) {
						run("Select All");
						roiManager("Add");
						}
					else {
						selectImage(window_MaxIP);
						run("Enhance Contrast", "saturated=0.01");
						setBatchMode('show');
						user_area_rev = getBoolean("Click \"Yes\" to analyze all but your selection\nPress \"No\" to analyze only your selection\n \Make no selection to analyze the entire image");
						setTool("freehand");
						waitForUser("Click \"OK\" after selecting area for analysis\nSelect nothing to analyze the entire image");
						setBatchMode('hide');
						if ((selectionType() >= 0 && selectionType() < 4) || selectionType == 9) { //If valid selection selection
							if (user_area_rev == true) run("Make Inverse");
							roiManager("Add");
							}
						else {
							waitForUser("The whole image will be analyzed.\nNext time just say so in the first place.");
							run("Select All");
							roiManager("Add");
							}
						}
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
			roiManager("Deselect");
			roiManager("Select", 1);
			roiManager("Delete");
			back_median = getResult("Median", nResults - 1);
			run("Clear Results");
			
			//Get Signal threshold
			SNR_noise();
			roiManager("Deselect");
			roiManager("Select", 1);
			roiManager("Delete");
			run("Select None");
			noise_max = getResult("Mean", nResults - 1) + noise_stdev * getResult("StdDev", nResults - 1); //Signal must be brighter than the noise
			run("Clear Results");
			
			//Determine Maxima
			selectImage(window_MaxIP);
			maxima = SNR_maximasearch();
			selectImage(window_MaxIP);
			roiManager("Select", 0);
			run("Clear Results");
			
			//Run peak intensity and Sum intensity measurements
			if (peak_intensity == true) {
				selectImage(window_Subtract);
				roiManager("Select", 0);
				run("Find Maxima...", "noise=" + maxima + " output=[Point Selection]");
				selectImage(window_MaxIP);
				run("Measure");
				String.resetBuffer;
				String.append(path);
				for (n = 1; n < nResults; n++) String.append(", " + getResult("Mean", n));
				print("[Peak]", String.buffer);
				run("Find Maxima...", "noise=" + maxima + " output=List");
				}
			if (sum_intensity == true) {
				selectImage(window_Subtract);
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
				selectImage(window_Subtract);
				roiManager("Select", 0);
				run("Find Maxima...", "noise=" + maxima + " output=List");
				}
			
			//Create signal mask image
			newImage("Signal", "8-bit white", width, height, 1); 
			selectWindow("Signal");
			window_signal = getImageID();
			
			//Initialize dot expansion
			setColor(0);
			filtered_spots = 0;
			x_values = newArray();
			y_values = newArray();
			cardinal = newArray();
			if (filter == true) { //Get bounds for filter array
				north = newArray();
				northeast = newArray();
				east = newArray();
				southeast = newArray();
				south = newArray();
				southwest = newArray();
				west = newArray();
				northwest = newArray();
				}
			for (q = 0; q < nResults && q < 10000; q++) {
				x_values = Array.concat(x_values, getResult("X", q));
				y_values = Array.concat(y_values, getResult("Y", q));
				}
			spot_count = q;
			//Expand dots
			if (debug_switch) {
				selectImage(window_signal);
				setBatchMode('show');
				}
			if (expansion_method == "Gaussian") { //If gaussian is selected run the gaussian fitting
				for (q = 0; q < x_values.length && q < 10000; q++) {
					cardinal = SNR_gauss_polygon(x_values[q], y_values[q], window_signal); //Run dots with different x and y values
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
					} //End of dots loop
				}
			else if (x_values.length > normal_limit && expansion_method == "Normal") { //Run the faster dots program if there's too many dots
				reduced_cardinal = true;
				for (q = 0; q < x_values.length && q < 10000; q++) {
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
			else { //Force polygon or if running on normal and less than normal_limit
				for (q = 0; q < x_values.length && q < 10000; q++) {
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
				peak_intensity = newArray();
				area_all = newArray();
				
				//Iterate through every spot and get mean
				selectImage(window_MaxIP);
				for (q = 0; q < x_values.length; q++) {
					run("Select None");
					if (reduced_cardinal == false) makePolygon(x_values[q], y_values[q] - north[q], x_values[q] + northeast[q], y_values[q] - northeast[q], x_values[q] + east[q], y_values[q], x_values[q] + southeast[q], y_values[q] + southeast[q], x_values[q], y_values[q] + south[q], x_values[q] - southwest[q], y_values[q] + southwest[q], x_values[q] - west[q], y_values[q], x_values[q] - northwest[q], y_values[q] - northwest[q]);
					else makeOval(x_values[q] - west[q], y_values[q] - north[q], east[q] + west[q], north[q] + south[q]);
					run("Measure");
					if (nResults == 1) {
						mean_intensity = Array.concat(mean_intensity, getResult("Mean", nResults - 1));
						peak_intensity = Array.concat(peak_intensity, getPixel(x_values[q], y_values[q]));
						area_all = Array.concat(area_all, getResult("Area", nResults - 1));
						//print(getResult("Mean", nResults-1));
						}
					else {
						mean_intensity = Array.concat(mean_intensity, 0);
						peak_intensity = Array.concat(peak_intensity, 0);
						area_all = Array.concat(area_all, 0);
						}
					run("Clear Results");
					}
				
				//Calculate cutoffs
				temparr = newArray(); //temporary array
				temparr = Array.copy(mean_intensity); //temp array stores mean_intensity values
				Array.sort(temparr);
				med = 0; //median of mean_intensity
				madarr = newArray(); //median absolute deviation array
				mad = 0;
				if (temparr.length%2 == 0) { //If even
					temp = temparr.length/2 - 1;
					med =(temparr[temp] + temparr[temp+1])/2;
					}
				else { //Odd
					med = temparr[floor(temparr.length/2)];
					}
				//Median Absolute Deviation
				for (q = 0; q < mean_intensity.length; q++) {
					madarr = Array.concat(madarr, abs(med - mean_intensity[q]));
					}
				Array.sort(madarr);
				if (madarr.length%2 == 0) { //If even
					temp = madarr.length/2 - 1;
					mad =(madarr[temp] + madarr[temp+1])/2;
					}
				else mad = madarr[floor(madarr.length/2)]; //If odd
				
				made = mad * 1.483;
				
				low_cutoff = med - (made * filter_low);
				high_cutoff = med + (made * filter_high);
				
				low_counter = newArray();
				high_counter = newArray();
				
				//print(low_cutoff, high_cutoff);
				//print(temparr[0], temparr[temparr.length-1]);
				
				//Masking
				area_reg = 0;
				area_bright = 0;
				for (q = 0; q < mean_intensity.length; q++) { //Select spots that should not be included in the regular measurement
					if (mean_intensity[q] < low_cutoff || peak_intensity[q] < noise_max || area_all[q] < 0.023) { //Remove spots
						//print("Low " + mean_intensity[q] + " / " + low_cutoff);
						low_counter = Array.concat(low_counter, q); //Mask for low cutoff
						filtered_spots++;
						spot_count--;
						}
					else if (mean_intensity[q] > high_cutoff) {
						//print("High " + mean_intensity[q] + " / " + high_cutoff);
						high_counter = Array.concat(low_counter, q); //Add to array that will exclude points
						x_values_high = Array.concat(x_values_high, x_values[q]);
						y_values_high = Array.concat(y_values_high, y_values[q]);
						area_bright += area_all[q];
						spot_count--;
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
					else if (area_all[q] > 0.023) area_reg += area_all[q];
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
				for (q = 0; q < x_values_high.length && q < 10000; q++) {
					//print(x_values_high[q], y_values_high[q]);
					if (expansion_method == "Gaussian") {
						cardinal = SNR_gauss_polygon(x_values_high[q], y_values_high[q], window_high_signal); //Run Gaussian with high xy values
						
						}
					else if (expansion_method == "Normal" && x_values_high.length < normal_limit) {
						cardinal = SNR_polygon(x_values_high[q], y_values_high[q], window_high_signal); //Run poly with high xy values
						}
					else cardinal = SNR_dots(x_values_high[q], y_values_high[q], window_high_signal); //Run dots with high xy values
					}
				count_bad = temp;
				
				for (q = 0; q < x_values.length && q < 10000; q++) {
					found = false;
					for (p = 0; p < low_counter.length; p++) {
						if (q == low_counter[p]) found = true;
						}
					for (p = 0; p < x_values_high.length; p++) {
						if (x_values[q] == x_values_high[p] && y_values[q] == y_values_high[p]) found = true;
						}
					if (found == false) {
						cardinal = SNR_polygon(x_values[q], y_values[q], window_reg_signal); //Run poly with new x and y values
						
						if (expansion_method == "Gaussian") {
							cardinal = SNR_gauss_polygon(x_values[q], y_values[q], window_reg_signal); //Run Gaussian with xy values
							}
						else if (expansion_method == "Normal" && x_values.length < normal_limit) {
							cardinal = SNR_polygon(x_values[q], y_values[q], window_reg_signal); //Run poly with xy values
							}
						else cardinal = SNR_dots(x_values[q], y_values[q], window_reg_signal); //Run dots with xy values
							}
					}
				
				print(spot_count + " Regular points processed");
				if (x_values_high.length > 0) print(x_values_high.length + " bright points");
				if (filtered_spots > 0) print(filtered_spots + " points ignored");
				
				Array.getStatistics(mean_intensity, temp, temp, mean, temp);
				if (area_reg > area_cutoff) {
					selectImage(window_reg_signal); 
					run("Create Selection");
					roiManager("Add");
					run("Make Inverse");
					roiManager("Add");
					selectImage(window_reg_signal);
					close();
					}
				else {
					print("Signal Area too small, ignoring");
					selectImage(window_reg_signal);
					makeRectangle(0, 0, 2, 2);
					roiManager("Add");
					run("Make Inverse");
					roiManager("Add");
					filtered_spots = spot_count;
					spot_count = 0;
					close();
					}
				
				if (x_values_high.length > 0) {
					if (area_bright > area_cutoff_bright) {
						selectImage(window_high_signal);
						run("Create Selection");
						roiManager("Add");
						run("Make Inverse");
						roiManager("Add");
						selectImage(window_high_signal);
						close();
						}
					else {
						print("Bright Signal area too small, ignoring");
						selectImage(window_high_signal);
						close();
						x_values_high = newArray();
						}
					}
				else {
					selectImage(window_high_signal);
					close();
					}
				
				//DEBUG
				if (debug_switch) {
					selectImage(window_MaxIP);
					roiManager("Select", 2);
					setBatchMode('show');
					}
				
				
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
			else { //Do not filter spots
				//Create Selection of signal
				print(spot_count + " points processed");
				if (filtered_spots > 0) print(filtered_spots + " points ignored");
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
			if (filter == true && x_values_high.length > 0) array_results = SNR_results(2); //If doing spot by spot and there are bright spots
			else if (filter == true && x_values_high.length == 0) array_results = SNR_results(3); //If doing spot by spot and there are no bright spots
			else array_results = SNR_results(1); //If not doing spot by spot
			
			//Prep Images
			selectImage(window_Subtract);
			run("Enhance Contrast", "saturated=0.01");
			setMetadata("Info", channel);
			if (File.exists(mergeDir + "Subtract" + File.separator + stripath + ".tif") == false || recreate_tif == true) saveAs("tif", mergeDir + "Subtract" + File.separator + stripath + ".tif");
			run("Select None");
			close();
			selectImage(window_MaxIP);
			run("Select None");
			resetThreshold();
			setThreshold(0, 9000);
			run("Create Selection");
			run("Enhance Contrast", "saturated=0.01"); //Make the MaxIP image pretty
			run("Select None");
			getMinAndMax(min, max);
			setMetadata("Info", channel);
			if (custom_lut == true) {
				//Manual
				if (indexOf(channel, "Cy3") > -1 && min_cy3 != 0 && max_cy3 != 0) setMinAndMax(min_cy3,max_cy3); //Cy3
				if (indexOf(channel, "Cy3.5") > -1 && min_cy35 != 0 && max_cy35 != 0) setMinAndMax(min_cy35,max_cy35); //Cy3.5
				else if (indexOf(channel, "Cy5.5") > -1 && min_cy55 != 0 && max_cy55 != 0) setMinAndMax(min_cy55,max_cy55); //Cy5.5
				else if (indexOf(channel, "FITC") > -1 && min_fitc != 0 && max_fitc != 0) setMinAndMax(min_fitc,max_fitc); //FITC
				//Semi-Manual
				if (indexOf(channel, "Cy3") > -1 && (min_cy3 == 0 || max_cy3 == 0)){
					if (min_cy3 == 0) setMinAndMax(min,max_cy3); //Cy3
					else if (max_cy3 == 0) setMinAndMax(min_cy3, max);
					}
				if (indexOf(channel, "Cy3.5") > -1 && (min_cy35 == 0 || max_cy35 == 0)){
					if (min_cy35 == 0) setMinAndMax(min,max_cy35); //Cy3.5
					else if (max_cy35 == 0) setMinAndMax(min_cy35, max);
					}
				else if (indexOf(channel, "Cy5.5") > -1 && (min_cy55 == 0 || max_cy55 == 0)){
					if (min_cy55 == 0) setMinAndMax(min,max_cy55); //Cy5.5
					else if (max_cy55 == 0) setMinAndMax(min_cy55, max);
					}
				else if (indexOf(channel, "FITC") > -1 && (min_fitc == 0 || max_fitc == 0)){
					if (min_fitc == 0) setMinAndMax(min,max_fitc); //fitc
					else if (max_fitc == 0) setMinAndMax(min_fitc, max);
					}
				//Auto
				if (indexOf(channel, "Cy3") > -1 && (min_cy3 == 0 && max_cy3 == 0)){
					setMinAndMax(min,max); //Cy3
					}
				if (indexOf(channel, "Cy3.5") > -1 && (min_cy35 == 0 && max_cy35 == 0)){
					setMinAndMax(min,max); //Cy3.5
					}
				else if (indexOf(channel, "Cy5.5") > -1 && (min_cy55 == 0 && max_cy55 == 0)){
					setMinAndMax(min,max); //Cy5.5
					}
				else if (indexOf(channel, "FITC") > -1 && (min_fitc == 0 && max_fitc == 0)){
					setMinAndMax(min,max); //fitc
					}
				}
			if (File.exists(mergeDir + "Max" + File.separator + stripath + ".tif") == false || recreate_tif == true) saveAs("tif", mergeDir + "Max" + File.separator + stripath + ".tif"); //Save for future use
			//print(min, max);
			//print(min + array_results[2] * 10);
			run("8-bit");
			setMetadata("Info", channel);
			if (File.exists(mergeDir + "Max 8-bit" + File.separator + stripath + ".tif") == false || recreate_tif == true) saveAs("tif", mergeDir + "Max 8-bit" + File.separator + stripath + ".tif");
			setForegroundColor(0, 0, 0);
			if (filter == true && x_values_high.length > 0) drawString(path + "\nRegular SNR/Score: " + array_results[0] + "/" + array_results[5] + "\nBright SNR/Score: " + array_results[3] + "/" + array_results[6], 10, 40, 'white');
			else if (filter == true && x_values_high.length == 0) drawString(path + "\nSNR/Score: " + array_results[0] + "/" + array_results[5], 10, 40, 'white');
			else drawString(path + "\nSNR/Score: " + array_results[0] + "/" + array_results[3], 10, 40, 'white');
			selectImage(window_Median);
			run("Enhance Contrast", "saturated=0.01"); //Make the Median image pretty
			setMetadata("Info", channel);
			if (File.exists(mergeDir + "Median" + File.separator + stripath + ".tif") == false || recreate_tif == true) saveAs("tif", mergeDir + "Median" + File.separator + stripath + ".tif");
			run("8-bit");
			if (filter == true && x_values_high.length > 0) drawString("Median Merge\nRegular Signal: " + array_results[1] + "\nBright Signal: " + array_results[4] + "\nNoise: " + array_results[2], 10, 40, 'white');
			else drawString("Median\nSignal: " + array_results[1] + "\nNoise: " + array_results[2], 10, 40, 'white');	
			
			//Add Slice with Cell Noise and Signal areas on it
			selectImage(window_MaxIP);
			run("Images to Stack", "name=Stack title=[] use");
			setSlice(1);
			run("Add Slice");
			
			//Fill in Noise
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
				setForegroundColor(5, 5, 5);
				run("Draw", "slice");
				run("Enlarge...", "enlarge=1 pixel");
				setForegroundColor(255, 255, 255);
				run("Draw", "slice");
				for (q = 0; q < x_values.length && q < 10000; q++) {
					found = false;
					for (p = 0; p < low_counter.length; p++) {
						if (q == low_counter[p]) found = true;
						}
					if (found == false) setPixel(x_values[q], y_values[q], 200);
					}
				setForegroundColor(0, 0, 0);
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
				for (q = 0; q < x_values.length && q < 10000; q++) {
					setPixel(x_values[q], y_values[q], 200);
					}
				drawString("Maxima: " + maxima + "\nSpots: " + spot_count + "/" + filtered_spots, 10, 40, 'white');
				}
			run("Select None");
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
			roiManager("Reset");
			
			if (delay > 0) {
				print("Waiting for network for " + delay + " seconds.");
				wait(delay*1000); //Delay for network
				}
			
			remaining = img_files - img_processed;
			estimate = 0;
			estimate = round(((getTime() - start_time) / img_processed) * remaining);
			if (estimate == NaN) estimate = 0;
			if (sub == "") folder = "Root";
			else folder = "\"" + substring(sub, 0, lengthOf(sub) - 1) + "\"";
			if (estimate >= 55000) { //If more than one minute
				estimate_array = SNR_timediff(0, estimate);
				print(SNR_natural_time(folder + " Folder Time Remaining: ", estimate_array));
				}
			else {
				print(folder + " Folder Time Remaining: " + round(estimate / 10000)*10 + " seconds");
				}
			} //end of else
		}//end of for loop
	return final_file_list;
	} //end of main function

function SNR_background() { //Measures background, the darkest part, where there are no cells
	selectImage(window_Median);
	run("Duplicate...", " ");
	run("8-bit");
	run("Select None");
	roiManager("Select", 0);
	run("Auto Local Threshold", "method=Phansalkar radius=100 parameter_1=0 parameter_2=0"); //Local Threshold Background
	run("Create Selection");
	run("Enlarge...", "enlarge=1 pixel");
	run("Enlarge...", "enlarge=-16 pixel");
	roiManager("Add");
	close();
	selectImage(window_Median);
	roiManager("Select", newArray(0, 1));
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results
	} //End of Function

function SNR_noise() { //Measures Cell Noise
	selectImage(window_Median);
	run("Duplicate...", " ");
	run("8-bit");
	run("Select None");
	roiManager("Select", 0);
	run("Auto Local Threshold", "method=Phansalkar radius=100 parameter_1=0 parameter_2=0 white"); //Local Threshold cell noise
	run("Create Selection"); //Create selection 2
	run("Enlarge...", "enlarge=-1 pixel"); //Remove very small selections
	run("Enlarge...", "enlarge=16 pixel"); //Expand Cell noise boundary; Needed for exceptional images
	roiManager("Add");
	close();
	selectImage(window_Median);
	roiManager("Select", newArray(0, roiManager("Count") - 1)); //Select Cell Noise
	roiManager("AND"); //Select regions of Cell Noise
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results and clear ROI manager
	}//End of Noise function

function SNR_signal(roi) { //Measures Signal, ensure dots is in ROI manager, position 0
	selectImage(window_MaxIP);
	roiManager("Select", newArray(0, roi));
	roiManager("AND");
	//setBatchMode('show');
	//waitForUser("Check area");
	//setBatchMode('hide');
	run("Measure");
	//Check signal area is above threshold
	run("Select None");
	} //End of signal function

function SNR_dots(xi, yi, window) { //Searches N, S, E, W and then draws an ellipse on mask image
	selectImage(window_MaxIP);
	cardinal = newArray(1, 1, 1, 1); //Array for directions
	cap = 0;
	
	//North point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi, yi - n)); //Add pixel value
	cardinal[0] = SNR_basic_expand(pixel, cap, 1);
	
	//East point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi + n, yi)); //Add pixel value
	cardinal[1] = SNR_basic_expand(pixel, cap, 1);
	
	//South point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi, yi + n)); //Add pixel value
	cardinal[2] = SNR_basic_expand(pixel, cap, 1);
	
	//West point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi - n, yi)); //Add pixel value
	cardinal[3] = SNR_basic_expand(pixel, cap, 1);
	
	if (cap <= 2 || count_bad == true) {
		selectImage(window);
		fillOval(xi - cardinal[3], yi + cardinal[0], cardinal[1] + cardinal[3] + 1, cardinal[0] + cardinal[2] + 1);
		return cardinal;
		}
	else {
		spot_count --;
		filtered_spots ++;
		return cardinal;
		}
	}//End of dot function

function SNR_gauss_expand(all_pixel) { //Returns number of pixels to expand in a certain direction
	result = newArray(0, 0, 0);
	for (p = 1; p <= np_radii; p++) {
		counting = newArray();
		pixel = newArray();
		for (n = -p; n <= p; n++) counting = Array.concat(counting, n); //Create counting array
		for (n = -p; n <= p; n++) pixel = Array.concat(pixel, all_pixel[(all_pixel.length-1)/2+n]); //Create pixel array
		Fit.doFit(12, counting, pixel); //Do gaussian fit
		//print(Fit.p(1), Fit.p(3));
		if (Fit.rSquared < 0.95 || abs(Fit.p(2)) > abs(counting[0]) || Fit.p(3) > counting.length/2) return result;
		result[0] = Fit.p(2);
		result[1] = Fit.p(3);
		result[2] = Fit.p(1);
		/*
		0 = offset
		1 = amplitude
		2 = center
		3 = sd
		*/
		}
	if (p == np_radii) return result;
	else return newArray(0, 1, 0); //Return center and standard deviation
	}

function SNR_getline(xi, yi, direction, radii) { //Gets line with center of (xi, yi) of radii 
	pixel = newArray();
	if (direction == 0) { //For y-axis
		for (r = 0; r <= 2*radii; r++) pixel = Array.concat(pixel, getPixel(xi, yi - radii + r)); //Add pixel value
		}
	if (direction == 1) { //For nw-se line
		for (r = 0; r <= 2*radii; r++) pixel = Array.concat(pixel, getPixel(xi - radii + r, yi - radii + r)); //Add pixel value
		}
	if (direction == 2) { //For x-axis
		for (r = 0; r <= 2*radii; r++) pixel = Array.concat(pixel, getPixel(xi - radii + r, yi)); //Add pixel value
		}
	if (direction == 3) { //For sw-ne line
		for (r = 0; r <= 2*radii; r++) pixel = Array.concat(pixel, getPixel(xi - radii + r, yi + radii - r)); //Add pixel value
		}
	return pixel;
	}

function SNR_gauss_polygon(xi, yi, window) {
	selectImage(window_MaxIP);
	cardinal = newArray(0, 0, 0, 0, 0, 0, 0, 0);
	result = newArray(0, 0);
	pixel = newArray();
	cap = 0;
	//print(xi, yi);
	//Y-axis
	pixel = SNR_getline(xi, yi, 0, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[0] = result[0] - result[1]*gauss_d;
	cardinal[4] = result[0] + result[1]*gauss_d;
	
	//NW to SE
	pixel = SNR_getline(xi, yi, 1, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[7] = result[0] - result[1]*gauss_d;
	cardinal[3] = result[0] + result[1]*gauss_d;
	
	//X-axis
	pixel = SNR_getline(xi, yi, 2, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[6] = result[0] - result[1]*gauss_d;
	cardinal[2] = result[0] + result[1]*gauss_d;
	
	//SW to NE
	pixel = SNR_getline(xi, yi, 3, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[5] = result[0] - result[1]*gauss_d;
	cardinal[1] = result[0] + result[1]*gauss_d;
	
	//Array.print(Array.concat(xi, yi, result[2], cardinal));
	
	for (i = 0; i < cardinal.length; i++) {
		if (cardinal[i] > 5) cap ++;
		}
	if (debug_switch) {
		print("(" + xi + "," + yi + ") bounding:");
		Array.print(cardinal); //debug
		}
	if (cap <= 2 || count_bad == true) {
		selectImage(window);
		makePolygon(xi, yi + cardinal[0], xi + cardinal[1] + 1, yi - cardinal[1], xi + cardinal[2] + 1, yi, xi + cardinal[3] + 1, yi + cardinal[3] + 1, xi, yi + cardinal[4] + 1, xi + cardinal[5], yi - cardinal[5], xi + cardinal[6], yi, xi + cardinal[7], yi + cardinal[7]);
		//exit();
		fill();
		return cardinal;
		}
	else {
		spot_count --;
		filtered_spots ++;
		return cardinal;
		}
	}

function SNR_basic_expand(all_pixel, multiplier) { //Returns distance to expand (cardinal value)
	pixel = newArray();
	pixel_avg = 100;
	//print(pixel.length, pixel_avg);
	for (r = 0; (pixel_avg > tolerance_bounding * multiplier || (all_pixel[r])/all_pixel[0] > tolerance_drop) && r < np_radii; r++) {
		pixel_dif = newArray(); //pixel_dif is the difference between pixels relative to the brightest pixel
		pixel = Array.concat(pixel, all_pixel[r]); //Add new pixel to pixel array
		if (pixel.length == 4) pixel = Array.slice(pixel, 1); //Only remember the last four pixels
		for (p = 1; p < pixel.length; p++) pixel_dif = Array.concat(pixel_dif, (pixel[p] - pixel[p-1])/all_pixel[0]); //Add pixel_dif values
		for (p = 0; p < pixel_dif.length; p++) { //Calculate the pixel_dif
			if (pixel_dif[p] < 0) pixel_dif[p] = abs(pixel_dif[p]); //If downward movement (negative) make positive
			else pixel_dif[p] += pixel_dif[p] * tolerance_upward; //If upward movement (positive) multiply by tolerance_upward
			}
		if (pixel_dif.length > 1) { //Get average of pixel_dif
			Array.getStatistics(pixel_dif, dummy, dummy, pixel_avg, dummy);
			}
		//print(pixel.length, pixel_avg);
		}
	if (pixel.length > 0) {
		if (pixel.length < 3) r -= pixel.length/2;
		else r -= 2;
		}
	if (r >= 5) cap++;
	return r;
	}

function SNR_polygon(xi, yi, window) {
	selectImage(window_MaxIP);
	cardinal = newArray(1, 1, 1, 1, 1, 1, 1, 1); //Array for directions
	cap = 0;
	
	//North point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi, yi - n)); //Add pixel value
	cardinal[0] = SNR_basic_expand(pixel, 1);
	
	//Northeast point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi + n, yi - n)); //Add pixel value
	cardinal[1] = SNR_basic_expand(pixel, 1.414213562);
	
	//East point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi + n, yi)); //Add pixel value
	cardinal[2] = SNR_basic_expand(pixel, 1);
	
	//Southeast point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi + n, yi + n)); //Add pixel value
	cardinal[3] = SNR_basic_expand(pixel, 1.414213562);
	
	//South point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi, yi + n)); //Add pixel value
	cardinal[4] = SNR_basic_expand(pixel, 1);
	
	//Southwest point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi - n, yi + n)); //Add pixel value
	cardinal[5] = SNR_basic_expand(pixel, 1.414213562);
	
	//West point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi - n, yi)); //Add pixel value
	cardinal[6] = SNR_basic_expand(pixel, 1);
	
	//Northwest point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi - n, yi - n)); //Add pixel value
	cardinal[7] = SNR_basic_expand(pixel, 1.414213562);
	
	if (cap <= 3 || count_bad == true) {
		selectImage(window);
		makePolygon(xi, yi - cardinal[0], xi + cardinal[1] + 1, yi - cardinal[1], xi + cardinal[2] + 1, yi, xi + cardinal[3] + 1, yi + cardinal[3] + 1, xi, yi + cardinal[4] + 1, xi - cardinal[5], yi + cardinal[5] + 1, xi - cardinal[6], yi, xi - cardinal[7], yi - cardinal[7]);
		//exit();
		fill();
		return cardinal;
		}
	else {
		spot_count --;
		filtered_spots ++;
		return cardinal;
		}
	}

function SNR_findmaxima(window, limit) { //Finds local Maxima and outputs the X and Y values on the results table, x pass and y pass
	run("Clear Results");
	selectImage(window);
	height = getHeight();
	width = getWidth();
	for (y = 1; y < height - 1; y++) {
		for (x = 1; x < width - 1; x++) {
			if (getPixel(x, y) - ((getPixel(x-1, y)+getPixel(x+1, y))/2) > limit) {
				if (getPixel(x, y) - ((getPixel(x, y-1)+getPixel(x, y+1))/2) > limit) {
					setResult("X", nResults, x);
					setResult("Y", nResults - 1, y);
					}
				}
			}
		}
	}

function SNR_maximasearch() { //Searches until the slope of the spot count levels out
	maxima = maxima_start;
	slope = newArray();
	slope_second = newArray();
	slope_second_avg = 0;
	run("Clear Results");
	//Initialize Maxima Results
	selectImage(window_Subtract);
	roiManager("Select", 0);
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	maxima += maxima_inc;
	
	//Second run
	roiManager("Select", 0);
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	maxima += maxima_inc;
	//Get first slope value
	slope = (getResult("Count", nResults - 1) - getResult("Count", nResults - 2));
	updateResults();
	slope_second = newArray();
	do { //Loop until the slope of the count levels out
		//Get the next Spot Count
		selectImage(window_Subtract);
		roiManager("Select", 0);
		run("Find Maxima...", "noise=" + maxima + " output=Count");
		setResult("Maxima", nResults - 1, maxima);
		updateResults();
		
		//Add slopes to slope array
		slope = Array.concat(slope, getResult("Count", nResults - 1) - getResult("Count", nResults - 2));
		if (slope.length >= 13) slope = Array.slice(slope, 1, 13);
		maxima += maxima_inc;
		
		
		slope_second = Array.concat(slope_second, pow(slope[slope.length-2] - slope[slope.length-1], 2)); //Add new second slope value
		if (slope_second.length == 15) slope_second = Array.slice(slope_second, 1, slope_second.length); //
		
		//Weighted average of second slope
		temp = 0;
		for (n = 0; n < slope_second.length; n ++) {
			slope_second_avg += slope_second[n] * (n + 1);
			temp += n + 1;
			}
		slope_second_avg = slope_second_avg / temp;
		
		//Debug
		if (debug_switch) {
			print("\nSlope");
			Array.print(slope);
			print("Slope_Second");
			Array.print(slope_second);
			print("slope_second_avg: " + slope_second_avg);
			}
		} while (slope_second_avg > pow(tolerance_maxima, 2))  //Keep going as long as the average second_slope is greater than 4 (default)
	maxima -= slope.length * 0.5 * maxima_inc; //Once the condition has been met drop maxima back 50%
	updateResults();
	
	
	if (plot == true) { //Create plots for maxima results
		for (n = maxima + slope.length * 0.5 * maxima_inc; n < maxima + maxima - maxima_start + 40; n += maxima_inc) { //Continue measuring spots
			selectImage(window_Subtract);
			roiManager("Select", 0);
			run("Find Maxima...", "noise=" + n + " output=Count");
			setResult("Maxima", nResults - 1, n);
			updateResults();
			}
		
		start = nResults / 2 - 19;
		if (start < 0) start = 0;
		stop = nResults / 2 + 20;
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
		saveAs("PNG", outDir + "Plots" + File.separator + stripath); //Save plot
		close();
		}
	if (rsquare == true) {
		for (n = maxima + slope.length * 0.5 * maxima_inc; n < maxima + maxima - maxima_start + 10; n += maxima_inc) { //Continue measuring spots
			selectImage(window_Subtract);
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
		maxima = xvalues[segments[n]] + maxima_inc;
		}
	return maxima;
	}
	
function SNR_linearize(xvalues, yvalues) { //Returns an array with locations of segments with > 0.95 rsquared values fitting a linear regression formula
	segments = newArray(0, 0); //Initialize array
	p = 2;
	while (segments[segments.length - 1] < xvalues.length) { //Keep going until you hit the end
		if (debug_switch) print("Testing " + segments[segments.length - 1] + " to " + p); //Debug
		do { //From the last entry until the rsquared value drops below the tolerance
			temp_x = Array.slice(xvalues, segments[segments.length - 1], p);
			temp_y = Array.slice(yvalues, segments[segments.length - 1], p);
			Fit.doFit(0, temp_x, temp_y);
			p += 1;
			} while (Fit.rSquared > tolerance_maxima && p < xvalues.length - 1);
		if (debug_switch) Fit.plot;
		if (debug_switch) setBatchMode('show'); //Debug
		segments = Array.concat(segments, p-2);
		p = segments[segments.length - 1] + 2;
		}
	if (debug_switch) Array.print(segments);
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

function SNR_results(boo) { //Calculates base SNR and other base values
	//boo = 1: Results
	//boo = 2: Bright
	//boo = 3: Bright_Null
	warnings = 0;
	sigrel = 0;
	noirel = 0;
	signoimean = 0;
	signoimedian = 0;
	cv = 0;
	score = 0;
	signoi = 0;
	
	sigrel_bright = 0;
	signoimean_bright = 0;
	signoimedian_bright = 0;
	score_bright = 0;
	signoi_bright = 0;
	n = 3;
	if (boo == 2) {
		n = 4;
		signoimean_bright = (getResult("Mean", nResults - n + 1) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
		sigrel_bright = getResult("Median", nResults - n + 1) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
		noirel_bright = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
		signoimedian_bright = sigrel_bright / noirel_bright; //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
		score_bright = signoimedian_bright * (log(sigrel_bright-noirel_bright)/log(10) - 1);
		signoi_bright = getResult("Median", nResults - n + 1) - getResult("Median", nResults - 2);
		}
	
	signoimean = (getResult("Mean", nResults - n) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1)); //SNR Mean = (Signal Mean - Back Mean) / (Noise Mean - Back Mean)
	sigrel = getResult("Median", nResults - n) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	signoimedian = sigrel / noirel; //SNR Median = (Signal Median - Back Median) / (Noise Median - Back Median)
	cv = getResult("StdDev", nResults - n) / getResult("Mean", nResults - n); //Coefficient of Variation - Signal
	score = signoimedian * (log(sigrel-noirel)/log(10) - 1);
	signoi = getResult("Median", nResults - n) - getResult("Median", nResults - 2);

	/*
	Warning Codes
	1 = Bad Coefficient of Variation (> 0.15 for Noise and Background)
	2 = Lots of filtered spots
	4 = Low spot count (Suspicious)
	8 = Signal area is too low
	16 = Signal Clipping
	*/
	temp = 0;
	if (getResult("Max", nResults - n) == 16383 || getResult("Max", nResults - n) == 65535) { 
		warnings += 16;
		}
	else if (boo == 2 && getResult("Max", nResults - n + 1) == 16383 || getResult("Max", nResults - n + 1) == 65535) { 
		warnings += 16;
		}
	if (getResult("Area", nResults - n) < area_cutoff) {
		sigrel = 0;
		signoimean = 0;
		signoimedian = 0;
		score = 0;
		signoi = 0;
		warnings += 8;
		}
	for (m = 1; m <= 2; m++) { //If the Coefficient of Variation for Noise or Background is greater than 0.2(default) then warn user
		if (getResult("Coefficient of Variation", nResults - m) > warning_cvnoise && warning_disable == false) {
			setResult("Warning Code", nResults - m, "High CV");
			temp = 1;
			}
		}
	if (cv > warning_cvspot || temp == 1) warnings += 1;
	if (getResult("Filtered Spots", nResults - n)/(getResult("Spots", nResults - n) + getResult("Filtered Spots", nResults - n)) > warning_badspot) warnings += 2;
	if (getResult("Spots", nResults - n) < warning_spot) warnings += 4;
	
	SNR_save_results(boo);
	
	return newArray(signoimedian, sigrel, noirel, signoimedian_bright, sigrel_bright, score, score_bright);
	}

function SNR_save_results(boo) { //Save Results to Raw and Condensed Tables, Save individual results
	//boo = 1: Results
	//boo = 2: Bright
	//boo = 3: Bright_Null
	line = "";
	comb = "";
	
	n = 3;
	if (boo == 2) n = 4;
	for (m = 1; m <= n; m++) { //Calculate CV for each selection
		setResult("Coefficient of Variation", nResults - m, getResult("StdDev", nResults - m) / getResult("Mean", nResults - m));
		}
	updateResults();
	
	{//Print First line of Raw
		line += getResultString("Area", nResults - n);
		line += "," + getResultString("Mean", nResults - n);
		line += "," + getResultString("StdDev", nResults - n);
		line += "," + getResultString("Min", nResults - n);
		line += "," + getResultString("Max", nResults - n);
		line += "," + getResultString("Median", nResults - n);
		line += "," + getResultString("File", nResults - n);
		line += "," + getResultString("Description", nResults - n);
		line += "," + getResultString("Coefficient of Variation", nResults - n);
		
		line += "," + signoi;
		line += "," + score;
		line += "," + signoimean;
		line += "," + signoimedian;
		line += "," + sigrel;
		line += "," + noirel;
		line += "," + spot_count;
		line += "," + filtered_spots;
		line += "," + maxima;
		if (expansion_method == "Force Polygon") line += ", Polygon";
		if (expansion_method == "Normal" && spot_count + filtered_spots < normal_limit) line += ", Polygon";
		if (expansion_method == "Normal" && spot_count + filtered_spots > normal_limit) line += ", Ellipse";
		if (expansion_method == "Gaussian") line += ", Gaussian";
		line += "," + warnings;
		print("[SNR]", line);
		comb = line;
		line = "";
		}
	
	if (boo == 2) {//Print Bright line of Raw
		line += getResultString("Area", nResults - n + 1);
		line += "," + getResultString("Mean", nResults - n + 1);
		line += "," + getResultString("StdDev", nResults - n + 1);
		line += "," + getResultString("Min", nResults - n + 1);
		line += "," + getResultString("Max", nResults - n + 1);
		line += "," + getResultString("Median", nResults - n + 1);
		line += "," + getResultString("File", nResults - n + 1);
		line += "," + getResultString("Description", nResults - n + 1);
		line += "," + getResultString("Coefficient of Variation", nResults - n + 1);
		
		line += "," + signoi_bright;
		line += "," + score_bright;
		line += "," + signoimean_bright;
		line += "," + signoimedian_bright;
		line += "," + sigrel_bright;
		print("[SNR]", line);
		comb += "\n" + line;
		line = "";
		}
	
	{ //Print Cell Noise Line of Raw
		line += getResultString("Area", nResults - 2);
		line += "," + getResultString("Mean", nResults - 2);
		line += "," + getResultString("StdDev", nResults - 2);
		line += "," + getResultString("Min", nResults - 2);
		line += "," + getResultString("Max", nResults - 2);
		line += "," + getResultString("Median", nResults - 2);
		line += "," + getResultString("File", nResults - 2);
		line += "," + getResultString("Description", nResults - 2);
		line += "," + getResultString("Coefficient of Variation", nResults - 2);
		print("[SNR]", line);
		comb += "\n" + line;
		line = "";
		}
	
	{ //Print Background Line of Raw
		line += getResultString("Area", nResults - 1);
		line += "," + getResultString("Mean", nResults - 1);
		line += "," + getResultString("StdDev", nResults - 1);
		line += "," + getResultString("Min", nResults - 1);
		line += "," + getResultString("Max", nResults - 1);
		line += "," + getResultString("Median", nResults - 1);
		line += "," + getResultString("File", nResults - 1);
		line += "," + getResultString("Description", nResults - 1);
		line += "," + getResultString("Coefficient of Variation", nResults - 1);
		print("[SNR]", line);
		comb += "\n" + line;
		line = "";
		}
	
	{ //Print Condensed line
		line += getResultString("File", nResults - n);
		if (boo != 1) line += "," + signoi_bright;
		line += "," + signoi;
		line += "," + score;
		if (boo != 1) line += "," + score_bright;
		line += "," + signoimean;
		line += "," + signoimedian;
		if (boo != 1) line += "," + signoimedian_bright;
		line += "," + sigrel;
		if (boo != 1) line += "," + sigrel_bright;
		line += "," + noirel;
		line += "," + spot_count;
		line += "," + filtered_spots;
		line += "," + maxima;
		if (expansion_method == "Force Polygon") line += ", Polygon";
		if (expansion_method == "Normal" && spot_count + filtered_spots < normal_limit) line += ", Polygon";
		if (expansion_method == "Normal" && spot_count + filtered_spots > normal_limit) line += ", Ellipse";
		if (expansion_method == "Gaussian") line += ", Gaussian";
		line += "," + warnings;
		print("[Condense]", line);
		}
	
	//Save Info
	File.saveString(line, textDir + stripath + "_Condense.csv");
	File.saveString(comb, textDir + stripath + "_Raw.csv");
	line = "";
	run("Clear Results");
	}

function SNR_timediff(start, end) { //Returns an array containing the difference between the start and end times in (days, hours, minutes)
	time = newArray(0, 0, 0);
	seconds = round((end - start) / 1000);
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
	if (time[0] == 0 && time[1] == 0 && time[2] == 0) return prefix + " <1 minute"; //Easy case
	if (time[0] > 0) { //If days
		if (time[0] == 1) temp += "1 day ";
		else temp += toString(time[0]) + " days ";
		}
	if (time[0] > 0 && time[1] > 0 && time[2] == 0) temp += "and "; //If only days and hours
	if (time[1] > 0) { //If hours
		if (time[1] == 1) temp += "1 hour ";
		else temp += toString(time[1]) + " hours ";
		}
	if ((time[0] > 0 || time[1] > 0) && time[2] > 0) temp += "and "; //If days or hours and minutes 
	if (time[2] > 0) { //If minutes
		temp += toString(time[2]) + " minute";
		if (time[2] > 1) temp += "s";
		}
	return temp;
	}
