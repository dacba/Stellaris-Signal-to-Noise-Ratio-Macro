
macro "Calculate Signal to Noise Ratio Beta...[c]" {
	version = "1.2.9"; //Beta Version
	
	/*
	Latest Version Date: 2016-02-23
	Written by Trevor Okamoto, Product Specialist II, Stellaris. LGC Biosearch Technologies
	
	Copyright (c) 2016 Trevor Okamoto

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	
	ImageJ/Fiji Macro for analyzing single molecule RNA FISH images from a Nikon Eclipse or tif files
	Separates the Signal from the surrounding cellular noise, and the background from the cellular noise.  These segments are measured for their mean and median brightness values.  These values are used to calculate the relative signal and noise, and from that the signal to noise ratio.  Other options are available such as spot filtering, and tolerance tweaking.
	
	Tested on ImageJ version 1.50e
	Not Compatible with 1.49n
	*/
	
	//Initialize
	setBatchMode(true);
	setOption("ShowRowNumbers", false);
	requires("1.48v");
	run("Set Measurements...", "area mean standard min median redirect=None decimal=3");
	run("Input/Output...", "jpeg=85 gif=-1 file=.csv save_column");
	setFont("SansSerif", 22);
	run("Bio-Formats Macro Extensions");
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
	if (isOpen("Debug Log")) {
		selectWindow("Debug Log");
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
	debug_switch = false; //Enables all debug output
	custom_lut = false; //Assign lut values to images
	ztrim = false; //Trim z-stack
	enable_hash = true; //Draws hash marks on unmeasured areas
	background_method = 1; //Background method
	reanalysis = true; //Force reanalysis on images
	
	//Advanced Options
	advanced = false;
	user_area_double_check = true; //Double checks with the user if 
	recreate_tif = false; //Forces re-saving tif files
	maxima_inc = 20; //Maxima Increment
	maxima_factor = 100; //Maxima Factor
	delay = 0; //Network delay
	rsquare = true; //Check for linear fit maxima search
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
	noise_stddev = 1; //Defines the number of standard deviation points above the mean noise value for peak signal to be counted
	gauss_offset = 2; //Defines the threshold of standard deviation of the Gaussian fit
	gauss_d = 2; //Number of standard deviations to move outward of Gaussian fit
	np_radii = 9;
	pass_snr = 4;
	pass_signoi = 200;
	
	min_fitc = 0;
	max_fitc = 0;
	min_cy3 = 0;
	max_cy3 = 0;
	min_cy35 = 0;
	max_cy35 = 0;
	min_cy55 = 0;
	max_cy55 = 0;
	
	
	area_cutoff = 1; //Area (micron^2) the regular selection must be to be counted, specifically 10 3x3 px areas
	area_cutoff_bright = 1; //Area (micron^2) the bright selection must be to be counted
	
	
	//Dialog
	Dialog.create("Spot Processor");
	
	Dialog.addChoice("Signal Masking Option:", newArray("Normal", "Gaussian", "Peaks"/*, "SMLM Fit"*/));
	Dialog.addChoice("Noise Masking Option:", newArray("Normal", "None"));
	Dialog.addChoice("Background Masking Option:", newArray("Normal", "Histogram Peak", "Gaussian Histogram Peak", "Bottom 10%"));
	Dialog.addCheckboxGroup(4, 3, newArray("Sum Intensity", "Peak Intensity", "Plot Maxima Results", "User Defined Area", "Signal Filtering", "Advanced Options", "Custom LUT", "Auto Trim Z-stack", "Re-analyze Images", "Mark Unmeasured Areas"), newArray(sum_intensity, peak_intensity, plot, user_area, filter, advanced, custom_lut, ztrim, reanalysis, enable_hash));
	Dialog.show();
	
	//Retrieve Choices
	expansion_method = Dialog.getChoice();
	noise_method = Dialog.getChoice();
	background_method_temp = Dialog.getChoice();
	sum_intensity = Dialog.getCheckbox();
	peak_intensity = Dialog.getCheckbox();
	plot = Dialog.getCheckbox();
	user_area = Dialog.getCheckbox();
	filter = Dialog.getCheckbox();
	advanced = Dialog.getCheckbox();
	custom_lut = Dialog.getCheckbox();
	ztrim = Dialog.getCheckbox();
	reanalysis = Dialog.getCheckbox();
	enable_hash = Dialog.getCheckbox();
	
	maxima_start = maxima;
	tolerance_drop = (tolerance_bounding / 5) + 0.89;
	if (background_method_temp == "Normal") background_method = 1;
	else if (background_method_temp == "Histogram Peak") background_method = 2;
	else if (background_method_temp == "Gaussian Histogram Peak") background_method = 3;
	else if (background_method_temp == "Bottom 10%") background_method = 4;
	
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
		Dialog.addSlider("Bounding Stringency(Higher = smaller spots):", 0.01, 0.5, tolerance_bounding);
		Dialog.addSlider("Upward Stringency(Higher = smaller spots):", 0, 1, tolerance_upward);
		Dialog.addSlider("Maxima Tolerance(Higher = More Spots):", 1, 50, tolerance_maxima);
		Dialog.addString("Output Folder Name:", output);
		Dialog.addString("Exclude Files and Folders:", exclude);
		Dialog.addSlider("Starting Maxima:", 0, 200, maxima);
		Dialog.addSlider("Tolerance Drop", 0.5, 1, tolerance_drop);
		Dialog.addSlider("Dim StdDev", 1, 5, filter_low);
		Dialog.addSlider("Bright StdDev", 1, 5, filter_high);
		Dialog.addSlider("Signal/Noise StdDev Separation", 0, 5, noise_stddev);
		Dialog.addSlider("Signal Area Cutoff", 0, 10, area_cutoff);
		Dialog.addSlider("Bright Signal Area Cutoff", 0, 10, area_cutoff_bright);
		Dialog.addSlider("SNR Requirement", 0, 10, pass_snr);
		Dialog.addSlider("Signal - Noise Requirement", 0, 500, pass_signoi);
		Dialog.addSlider("Network Delay", 0, 10, delay);
		Dialog.addCheckboxGroup(3, 3, newArray("Include Large Spots", "Disable Warning Codes", "Linear Fit Maxima Search(Experimental)", "Force New Max/Median Images", "User Area Double Check", "Specify Output Folder Location", "Enable Debug Output"), newArray(count_bad, warning_disable, rsquare, recreate_tif, user_area_double_check, output_location, debug_switch));
		Dialog.addMessage("Warning Cutoffs");
		Dialog.addSlider("Coefficient of Variation S", 0, 2, warning_cvspot);
		Dialog.addSlider("Coefficient of Variation N", 0, 2, warning_cvnoise);
		Dialog.addSlider("Suspicious Spot Count", 0, 200, warning_spot);
		Dialog.addSlider("Filtered Spot Ratio", 0, 1, warning_badspot);
		Dialog.show();
		
		tolerance_bounding = Dialog.getNumber();
		tolerance_upward = Dialog.getNumber();
		tolerance_maxima = Dialog.getNumber();
		output = Dialog.getString();
		exclude = Dialog.getString();
		maxima = Dialog.getNumber();
		tolerance_drop = Dialog.getNumber();
		filter_low = Dialog.getNumber();
		filter_high = Dialog.getNumber();
		noise_stddev = Dialog.getNumber();
		area_cutoff = Dialog.getNumber();
		area_cutoff_bright = Dialog.getNumber();
		pass_snr = Dialog.getNumber();
		pass_signoi = Dialog.getNumber();
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
	
	//Warn if Choices are outside of recommended range
	if (tolerance_bounding > 0.3 || tolerance_bounding < 0.2 || tolerance_upward < 0.4 || tolerance_upward > 0.8|| tolerance_maxima > 15 || tolerance_maxima < 2) {
		Dialog.create("Warning");
		Dialog.addMessage("One or more of your variables are outside of the recommended ranges.\nPlease refer to the recommended ranges below.");
		Dialog.addMessage("Bounding Stringency: 0.2 - 0.3  (" + tolerance_bounding + ")\nUpward Stringency: 0.4 - 0.8  (" + tolerance_upward + ")\nMaxima Stringency: 2 - 10  (" + tolerance_maxima + ")");
		Dialog.addMessage("If you would like to continue using these variables press \"OK\" to continue\nBe sure to check the merged tif files and warning codes in the results file to ensure the analysis was done correctly");
		Dialog.show();
	}
	
	//Open Tables
	run("Table...", "name=SNR width=400 height=200");
	if (peak_intensity == true) run("Table...", "name=Peak width=40 height=200");
	if (sum_intensity == true) run("Table...", "name=Sum width=400 height=200");
	run("Table...", "name=Condense width=400 height=200");
	if (debug_switch) run("Text Window...", "name=[Debug Log] width=60 height=16 monospaced");
	
	//Write table headers
	if (debug_switch) print("[Debug Log]", "\nWriting Table Header");
	table_head = "Version " + version + " Bounding Stringency: " + tolerance_bounding + " Upward Stringency: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Starting Maxima: " + maxima_start + " (" + expansion_method + "/" + noise_method + "/" + background_method_temp + ")"; //-----Add maxima search method-----
	print("[SNR]", table_head);
	print("[Condense]", table_head);
	
	//Write Table Labels
	if (debug_switch) print("[Debug Log]", "\nWriting Table Labels");
	table_head = "Area,Mean,StdDev,Min,Max,Median,File,Description,Coefficient of Variation,Pass,S - N,S - N StdDev,SNR,Signal,Signal StdDev,Noise,Noise StdDev,Spots,Filtered Spots,Maxima,Expansion Method";
	if (warning_disable == false) table_head += ",Warning Code";
	print("[SNR]", table_head);
	
	if (filter == true) table_head = "File,Pass,Bright Pass,S - N,S - N StdDev,Bright S - N,Bright S - N StdDev,SNR,Bright SNR,Signal,Signal StdDev,Bright Signal,Bright Signal StdDev,Noise,Noise StdDev,Spots,Filtered Spots,Maxima,Expansion Method";
	else table_head = "File,Pass,S - N,S - N StdDev,SNR,Signal,Signal StdDev,Noise,Noise StdDev,Spots,Filtered Spots,Maxima,Expansion Method";
	if (warning_disable == false) table_head += ",Warning Code";
	print("[Condense]", table_head);
	
	
	//Initialize Peak and Sum intensity tables
	if (peak_intensity == true) print("[Peak]", "Peak Brightness");
	if (sum_intensity == true) print("[Sum]", "Sum Intensity");
	
	//Create Directories
	if (debug_switch) print("[Debug Log]", "\nCreating Directories");
	output_name = "Results";
	if (expansion_method != "Normal") output_name += " " + expansion_method;
	if (noise_method != "Normal") output_name += " " + noise_method;
	if (background_method_temp != "Normal") output_name += " " + background_method_temp;
	
	output_name += " " + tolerance_bounding + "-" + tolerance_upward + "-" + tolerance_maxima;
	
	if (filter == true) output_name += " Filtered-" + filter_low + "-" + filter_high + "-" + noise_stddev;
	if (ztrim == true) output_name += " Trimmed";
	if (pass_snr != 4 || pass_signoi != 200) output_name += " CustomPass"
	if (rsquare == true) output_name += " LinMaxSearch";
	if (custom_lut == true) output_name += " LUT";
	if (custom_lut == true && min_cy3 !=0 && max_cy3 != 0) output_name = output_name + "_Cy3" + min_cy3 + "-" + max_cy3;
	if (custom_lut == true && min_cy35 !=0 && max_cy35 != 0) output_name = output_name + "_Cy35" + min_cy35 + "-" + max_cy35;
	if (custom_lut == true && min_cy55 !=0 && max_cy55 != 0) output_name = output_name + "_Cy55" + min_cy55 + "-" + max_cy55;
	if (custom_lut == true && min_fitc !=0 && max_fitc != 0) output_name = output_name + "_FITC" + min_fitc + "-" + max_fitc;
	if (user_area == true) output_name += " Selection-" + toHex(random*random*random*1000) + toHex(random*random*random*1000);
	
	inDir = getDirectory("Choose Directory Containing Image Files"); //Get inDirectory
	if (output_location == false) outDir = inDir + output + File.separator; //Create base output inDirectory
	else outDir = getDirectory("Choose Directory where the output files should be saved") + output + File.separator;
	File.makeDirectory(outDir); //Create base output inDirectory
	outDir = outDir + output_name + File.separator;//Create specific output inDirectory
	savedataDir = outDir + "Saved data" + File.separator;
	File.makeDirectory(outDir); //Create specific output inDirectory
	File.makeDirectory(savedataDir);
	mergeDir = inDir + "Out-Merged Images" + File.separator;
	if (plot == true) File.makeDirectory(outDir + "Plots" + File.separator); //Create Plots inDirectory
	
	//Create Merged images folder if doesn't already exist
	File.makeDirectory(mergeDir);
	File.makeDirectory(mergeDir + "Max" + File.separator);
	File.makeDirectory(mergeDir + "Max 8-bit" + File.separator);
	File.makeDirectory(mergeDir + "Median" + File.separator);
	File.makeDirectory(mergeDir + "Subtract" + File.separator);
	File.makeDirectory(mergeDir + "Metadata" + File.separator);
	
	
	//RUN IT!
	if (debug_switch) print("[Debug Log]", "\nMain Process Starting");
	total_start = getTime();
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, sec, msec);
	TimeString = ", Date: ";
	if (month < 10) TimeString = TimeString + "0";
	TimeString = TimeString + month + "-";
	if (dayOfMonth < 10) TimeString = TimeString + "0";
	TimeString = TimeString + dayOfMonth + "-" + year + " ";
	if (hour < 10) {TimeString = TimeString + "0";}
	TimeString = TimeString + hour + ":";
	if (minute < 10) {TimeString = TimeString + "0";}
	TimeString = TimeString + minute;
	if (File.exists(mergeDir + "log.txt")) {
		File.append("----------\nStarted " + version + TimeString + "...\n" + output_name, mergeDir + "log.txt");
	}
	final_file_list = "";
	final_file_list = SNR_main(inDir, "");
	if (debug_switch) print("[Debug Log]", "\nMain Process Complete");
	
	//Save it!
	if (debug_switch) print("[Debug Log]", "\nSaving Results");
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
	print(SNR_natural_time("Total Time Elapsed: ", total_time)); //Get natural spoken time string
	
	if (File.exists(mergeDir + "log.txt") == false) {
		File.saveString(inDir + "\n----------" + final_file_list + "\n", mergeDir + "log.txt");
		File.append("----------\nStarted " + version + TimeString + "...\n" + output_name, mergeDir + "log.txt");
	}
	
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, sec, msec);
	TimeString = ", Date: ";
	if (month < 10) TimeString = TimeString + "0";
	TimeString = TimeString + month + "-";
	if (dayOfMonth < 10) TimeString = TimeString + "0";
	TimeString = TimeString + dayOfMonth + "-" + year + " ";
	if (hour < 10) {TimeString = TimeString + "0";}
	TimeString = TimeString + hour + ":";
	if (minute < 10) {TimeString = TimeString + "0";}
	TimeString = TimeString + minute;
	
	if (debug_switch) print("[Debug Log]", "\nClean up");
	temp = File.delete(inDir + "temp.txt");
	File.append("...Completed, " + TimeString, mergeDir + "log.txt");
	run("Collect Garbage");
	print("-- Done --");
	showStatus("Finished.");
} //end of macro

function SNR_main(dir, sub) {
	list = getFileList(dir + sub);//get file list
	final_file_list = "";
	img_files = 0;
	img_processed = 0;
	img_skip = 0;
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], ".nd2") || endsWith(list[i], ".tif") && indexOf(list[i], exclude) == -1) img_files++;
	}
	if (debug_switch) print("[Debug Log]", "\nFound " + img_files + " files");
	start_time = getTime();
	for (i = 0; i < list.length; i++) { //for each file
		showProgress(1 / list.length - 1);
		path = sub + list[i];
		window_MaxIP = 0;
		window_raw = 0;
		if (debug_switch) print("[Debug Log]", "\nDetermining File type");
		if ((endsWith(list[i], "/") || endsWith(list[i], "\\")) && indexOf(path, output) == -1 && indexOf(path, "Out-") == -1 && indexOf(path, exclude) == -1) { //For Folders
			SNR_main(dir, path); //Recursive Step
		}
		else if (endsWith(list[i], "/") == false && endsWith(list[i], "\\") == false && indexOf(list[i], exclude) == -1) { //For valid files
			stripath = replace(substring(path, 0, lastIndexOf(path, ".")), "\\", "_");
			stripath = replace(stripath, "/", "_");
			reduced_cardinal = false;
			//If file already analyzed with the current version and settings, SKIP
			if (File.exists(savedataDir + stripath + "_Raw.csv") && File.exists(savedataDir + stripath + "_Condense.csv") && File.exists(outDir + stripath + "_Merge.tif") && reanalysis == false) {
				print("------------\n" + path + " was already analyzed with the same version and settings...Skipping");
				print("[SNR]", File.openAsString(savedataDir + stripath + "_Raw.csv"));
				print("[Condense]", File.openAsString(savedataDir + stripath + "_Condense.csv"));
			}
			//If max median are present, use them instead
			else if (File.exists(mergeDir + "Max" + File.separator + stripath + ".tif") && File.exists(mergeDir + "Median" + File.separator + stripath + ".tif") && recreate_tif == false) { //If tif Files exist
				print("------------\nFile: " + stripath + ".tif - Saved");
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
				print("------------\nFile: " + path);
				if (File.exists(mergeDir + "Metadata" + File.separator + stripath + ".txt")) {
					info = File.openAsString(mergeDir + "Metadata" + File.separator + stripath + ".txt");
				}
				else {
					run("Bio-Formats Importer", "open=[" + dir + path + "] display_metadata view=[Metadata only]");
					selectWindow("Original Metadata - " + list[i]);
					saveAs("Text", inDir + "temp.txt");
					run("Close");
					info = File.openAsString(inDir + "temp.txt");
					File.rename(inDir + "temp.txt", mergeDir + "Metadata" + File.separator + stripath + ".txt");
				}
				if (indexOf(info, "SizeC	1") == -1 && indexOf(info, "C=") == -1) { //If multidimension and hasn't been split
					print("Multi-dimension file detected, splitting");
					if(File.exists(dir + "Out-Multidimension Files" + File.separator + path) == false) {
						run("Bio-Formats Importer", "open=[" + dir + path + "] color_mode=Grayscale open_all_series split_channels view=Hyperstack stack_order=XYCZT use_virtual_stack");
						print("Saving Splits");
						split_start = getTime();
						for (n = 1; nImages > 0; n++) {
							selectImage(1);
							if (File.exists(dir + getTitle() + ".tif") == false) saveAs("tif", dir + getTitle() + ".tif");
							close;
							print(nImages + " remaining");
							estimate = 0;
							estimate = round(((getTime() - split_start) / n) * nImages);
							if (estimate == NaN) estimate = 0;
							if (estimate >= 55000) { //If more than one minute
								estimate_array = SNR_timediff(0, estimate);
								print(SNR_natural_time("Time Remaining: ", estimate_array));
							}
							else {
								print("Time Remaining: " + round(estimate / 10000)*10 + " seconds");
							}
						}
						//Move multidimension file to separate folder
						run("Close All");
						File.makeDirectory(dir + "Out-Multidimension Files" + File.separator);
						File.copy(dir + path, dir + "Out-Multidimension Files" + File.separator + path);
						i--;
						//exit("This Macro is only compatible with files that contain a single Z-stack.\nYour file has been split\nPlease restart the program.");
						}
						else print("File already split, skipping");
						list = getFileList(dir + sub);
				}
				else { //If not multidimension or has been split, assign channel
					if (debug_switch) print("[Debug Log]", "\nDetermining Channel");
					channel = "Unknown";
					if (indexOf(info, "uiGroupCount") > -1) {
						temp = indexOf(info, "uiGroupCount");
						channel_num = parseInt(substring(info, temp + 12, temp + 14));
						//print(substring(info, temp + 12, temp + 14));
						if (channel_num == 1) { //If not ND acquisition, single channel
							if (indexOf(info, "Name	FITC") > -1) channel = "FITC";
							if (indexOf(info, "Name	Cy3") > -1) channel = "Cy3";
							if (indexOf(info, "Name	Cy3.5") > -1) channel = "Cy3.5";
							if (indexOf(info, "Name	Cy5.5") > -1) channel = "Cy5.5";
							if (indexOf(info, "Name	DAPI") > -1) channel = "DAPI";
						}
						else if (channel_num > 1) { //If ND acquisition
							print(SNR_spelt_int(channel_num) + " Other Channel(s) Detected");
							//Find C=
							temp = indexOf(info, "C=");
							C_num = parseInt(substring(info, temp + 2, temp + 3));
							//print("C_num " + C_num);
							//C_num = parseInt(C_num);
							//print("C_num " + C_num);
							//Find Turret number
							temp = indexOf(info, "Turret1) #" + (C_num + 1));
							Turret = parseInt(substring(info, temp + 12, temp + 13));
							//print("Turret " + Turret);
							//Turret = parseInt(Turret);
							//print("Turret " + Turret);
							if (Turret == 1) channel = "DAPI";
							if (Turret == 2) channel = "FITC";
							if (Turret == 3) channel = "Cy3";
							if (Turret == 4) channel = "Cy3.5";
							if (Turret == 5) channel = "Cy5.5";
						}
						else {
							print("Error: Metadata is missing \"uiGroupCount\"");
							//print(SNR_spelt_int(channel_num) + " Channel(s) Detected");
							//exit();
						}
					}
					if (channel != "DAPI") {
						if (debug_switch) print("[Debug Log]", "\nOpening File");
						run("Bio-Formats Importer", "open=[" + dir + path + "] autoscale color_mode=Grayscale split_channels view=Hyperstack stack_order=XYCZT");
						window_raw = getImageID();
						if (nSlices == 1) {
							close();
							window_raw = 0;
							print("Images must have more than one slice for proper analysis");
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
					if (debug_switch) print("[Debug Log]", "\nInitialize Image");
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
						} while (z_min < nSlices && (edge[z_min-1]/edge_avg < 1.2 || z_min < 3));
						if (z_min > nSlices/2 || z_min == 3) z_min = 1; //algorithm likely messed up or there is no signal
						
						edge_avgarr = newArray();
						z_max = nSlices - 1;
						do {
							edge_avgarr = Array.concat(edge_avgarr, edge[z_max]);
							Array.getStatistics(edge_avgarr, dumb, dumb, edge_avg, dumb);
							z_max--;
						} while (z_max > 1 && (edge[z_max+1]/edge_avg < 1.2 || z_max > nSlices - 4));
						if (z_max < nSlices/2 || z_max == nSlices - 4) z_max = nSlices; //algorithm likely messed up or there is no signal
						if (z_min != 1 || z_max != nSlices) print("Z-stack trimmed: " + z_min + " - " + z_max + "(" + nSlices + ")");
						close;
						if (z_min != 1 || z_max != nSlices) {//Save min and max slices separately
							selectImage(window_raw);
							run("Duplicate...", "duplicate");
							run("8-bit");
							setSlice(z_min);
							run("Enhance Contrast", "saturated=0.01");
							saveAs("PNG", savedataDir + stripath + "_Z-Min.png");
							setSlice(z_max);
							run("Enhance Contrast", "saturated=0.01");
							saveAs("PNG", savedataDir + stripath + "_Z-Max.png");
							close;
						}
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
			if (debug_switch) print("[Debug Log]", "\nAnalyzing Image");
			img_processed++;
			final_file_list += "\n" + list[i]; //Save file names
			selectImage(window_MaxIP);
			getMinAndMax(min, max);
			getPixelSize(pixel_unit, pixel_width, pixel_height);
			//np_radii *= pixel_width/9.3347;
			print("Channel: " + channel);
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
			SNR_background(background_method);
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
			noise_max = getResult("Mean", nResults - 1) + noise_stddev * getResult("StdDev", nResults - 1); //Signal must be brighter than the noise
			run("Clear Results");
			
			//Determine Maxima
			selectImage(window_MaxIP);
			maxima = SNR_maximasearch();
			selectImage(window_MaxIP);
			roiManager("Select", 0);
			run("Clear Results");
			
			//Run peak intensity and Sum intensity measurements
			if (peak_intensity == true) {
				if (debug_switch) print("[Debug Log]", "\nPeak Intensity");
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
				if (debug_switch) print("[Debug Log]", "\nSum Intensity");
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
				amplitude_high = newArray();
				north = newArray();
				northeast = newArray();
				east = newArray();
				southeast = newArray();
				south = newArray();
				southwest = newArray();
				west = newArray();
				northwest = newArray();
			}
			for (q = 0; q < nResults && q < 10000; q++) { //analyze first 10,000 spots
				x_values = Array.concat(x_values, getResult("X", q));
				y_values = Array.concat(y_values, getResult("Y", q));
			}
			spot_count = q;
			//Expand dots
			if (debug_switch) print("[Debug Log]", "\nSpot Expansion");
			if (expansion_method == "Normal"){ //Use polygon if running on normal
				if (debug_switch) print("[Debug Log]", "\nPolygon");
				for (q = 0; q < x_values.length && q < 10000; q++) {
					cardinal = SNR_polygon(x_values[q], y_values[q], window_signal); //Run polygon with different x and y values
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
				}
			}
			else if (expansion_method == "SMLM Gaussian") { //If SMLM gaussian is selected run the SMLM gaussian fitting
				if (debug_switch) print("[Debug Log]", "\nSMLM Gaussian");
				exit("Nothing here yet");
			}
			else if (expansion_method == "Gaussian") { //If gaussian is selected run the gaussian fitting
				if (debug_switch) print("[Debug Log]", "\nGaussian");
				amplitude = newArray();
				for (q = 0; q < x_values.length && q < 10000; q++) {
					cardinal = SNR_gauss_polygon(x_values[q], y_values[q], window_signal); //Run gauss with different x and y values
					amplitude = Array.concat(amplitude, cardinal[8]);
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
				}
			}
			else if (expansion_method == "Peaks") {
				if (debug_switch) print("[Debug Log]", "\nPeaks");
				for (q = 0; q < x_values.length; q++) {
					cardinal = SNR_peak(x_values[q], y_values[q], window_signal);
					north = Array.concat(north, 0);
					northeast = Array.concat(northeast, 0);
					east = Array.concat(east, 0);
					southeast = Array.concat(southeast, 0);
					south = Array.concat(south, 0);
					southwest = Array.concat(southwest, 0);
					west = Array.concat(west, 0);
					northwest = Array.concat(northwest, 0);
				}
			}
			
			x_values_high = newArray();
			y_values_high = newArray();
			
			if (filter == true) { //Filter spots based on MADe settings
				if (debug_switch) print("[Debug Log]", "\nFiltering Spots");
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
				med = 0; //median of mean_intensity
				med = SNR_median(mean_intensity);
				
				//Median Absolute Deviation
				madarr = newArray(); //median absolute deviation array
				mad = 0;
				for (q = 0; q < mean_intensity.length; q++) {
					madarr = Array.concat(madarr, abs(med - mean_intensity[q]));
				}
				mad = SNR_median(madarr);
				
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
				spot_count = 0;
				for (q = 0; q < mean_intensity.length; q++) { //Select spots that should not be included in the regular measurement
					if (mean_intensity[q] < low_cutoff || peak_intensity[q] < noise_max || area_all[q] <= 0.023) { //Remove dim spots and small spots (2px)
						//print("Low " + mean_intensity[q] + " / " + low_cutoff);
						low_counter = Array.concat(low_counter, q); //Mask for low cutoff
						filtered_spots++;
						//spot_count--;
					}
					else if (mean_intensity[q] > high_cutoff) {  //Separate high spots
						//print("High " + mean_intensity[q] + " / " + high_cutoff);
						high_counter = Array.concat(low_counter, q); //Add to array that will exclude points
						x_values_high = Array.concat(x_values_high, x_values[q]);
						y_values_high = Array.concat(y_values_high, y_values[q]);
						area_bright += area_all[q];
					}
					else if (area_all[q] > 0.023) {
						area_reg += area_all[q];
						spot_count++;
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
				if (debug_switch) print("[Debug Log]", "\nRe-run spot expansion on high values");
				for (q = 0; q < x_values_high.length && q < 10000; q++) {
					//print(x_values_high[q], y_values_high[q]);
					if (expansion_method == "Normal") {
						cardinal = SNR_polygon(x_values_high[q], y_values_high[q], window_high_signal); //Run dots with high xy values
					}
					else if (expansion_method == "Gaussian") {
						cardinal = SNR_gauss_polygon(x_values_high[q], y_values_high[q], window_high_signal); //Run Gaussian with high xy values
						amplitude_high = Array.concat(amplitude_high, cardinal[8]);
					}
					else if(expansion_method == "Peaks") {
						cardinal = SNR_peak(x_values_high[q], y_values_high[q], window_high_signal);
					}
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
						//cardinal = SNR_polygon(x_values[q], y_values[q], window_reg_signal); //Run poly with new x and y values
						
						if (expansion_method == "Normal") {
							cardinal = SNR_polygon(x_values[q], y_values[q], window_reg_signal); //Run dots with xy values
						}
						else if (expansion_method == "Gaussian") {
							cardinal = SNR_gauss_polygon(x_values[q], y_values[q], window_reg_signal); //Run Gaussian with xy values
							amplitude = Array.concat(amplitude, cardinal[8]);
						}
						else if(expansion_method == "Peaks") {
							cardinal = SNR_peak(x_values[q], y_values[q], window_reg_signal);
						}
					}
				}
				
				print(spot_count + " Regular points processed");
				if (x_values_high.length > 0) print(x_values_high.length + " bright points");
				if (filtered_spots > 0) print(filtered_spots + " points ignored");
				
				Array.getStatistics(mean_intensity, temp, temp, mean, temp);
				if (area_reg > area_cutoff) {
					selectImage(window_reg_signal); 
					run("Create Selection");
					if (selectionType() != -1) {
						roiManager("Add");
					}
					else {
						makeRectangle(0, 0, 2, 2);
						roiManager("Add");
					}
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
					filtered_spots = 0;
					spot_count = 0;
					close();
				}
				
				if (x_values_high.length > 0) {
					if (area_bright > area_cutoff_bright) {
						selectImage(window_high_signal);
						run("Create Selection");
						if (selectionType() != -1) {
							roiManager("Add");
						}
						else {
							makeRectangle(0, 0, 2, 2);
							roiManager("Add");
						}
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
				SNR_background(background_method);
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Background");
				updateResults();
			}
			else { //Do not filter spots
				if (debug_switch) print("[Debug Log]", "\nNot Filtering Spots");
				//Create Selection of signal
				print(spot_count + " points processed");
				if (filtered_spots > 0) print(filtered_spots + " points ignored");
				selectImage(window_signal);
				run("Create Selection");
				if (selectionType() != -1) {
					roiManager("Add");
				}
				else {
					makeRectangle(0, 0, 2, 2);
					roiManager("Add");
				} //Create Signal selection
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
				SNR_background(background_method);
				setResult("File", nResults - 1, path);
				setResult("Description", nResults - 1, "Background");
				updateResults();
			}
			
			//Results
			array_results = newArray();
			if (filter == true && x_values_high.length > 0) array_results = SNR_results(2); //If doing spot by spot and there are bright spots
			else if (filter == true && x_values_high.length == 0) array_results = SNR_results(3); //If doing spot by spot and there are no bright spots
			else array_results = SNR_results(1); //If not doing spot by spot
			
			for (s = 0; s < array_results.length; s++) { //Round array results
				if (s <= 1) array_results[s] = round(array_results[s]*100)/100; //except SNR, 0.00 precision
				else array_results[s] = round(array_results[s]);
			}
			
			//Prep Imagesf
			if (debug_switch) print("[Debug Log]", "\nPrep Images");
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
			//Array_Results(0SNR, 1SNR_bright, 2signal, 3signal_stddev, 4noise, 5noise_stddev, 6signal_bright, 7signal_bright_stddev, 8signoi, 9signoi_stddev, 10signoi_bright, 11signoi_bright_stddev)
			run("8-bit");
			setMetadata("Info", channel);
			if (File.exists(mergeDir + "Max 8-bit" + File.separator + stripath + ".tif") == false || recreate_tif == true) saveAs("tif", mergeDir + "Max 8-bit" + File.separator + stripath + ".tif");
			setForegroundColor(0, 0, 0);
			if (filter == true && x_values_high.length > 0) drawString("Maximum Intensity Merge\nRegular SNR/Signal: " + array_results[0] + "/" + array_results[8] + "±" + array_results[9] + "\nBright SNR/Signal: " + array_results[1] + "/" + array_results[10] + "±" + array_results[11], 10, 40, 'white');
			else drawString("Maximum Intensity Merge\nSNR/Signal: " + array_results[0] + "/" + array_results[8] + "±" + array_results[9], 10, 40, 'white');
			drawString(path, 10, height - 20, 'white');
			selectImage(window_Median);
			run("Enhance Contrast", "saturated=0.01"); //Make the Median image pretty
			setMetadata("Info", channel);
			if (File.exists(mergeDir + "Median" + File.separator + stripath + ".tif") == false || recreate_tif == true) saveAs("tif", mergeDir + "Median" + File.separator + stripath + ".tif");
			run("8-bit");
			if (filter == true && x_values_high.length > 0) drawString("Median Intensity Merge\nRegular Signal: " + array_results[2] + "±" + array_results[3] + "\nBright Signal: " + array_results[6] + "±" + array_results[7] + "\nNoise: " + array_results[4] + "±" + array_results[5], 10, 40, 'white');
			else drawString("Median Intensity Merge\nSignal: " + array_results[2] + "±" + array_results[3] + "\nNoise: " + array_results[4] + "±" + array_results[5], 10, 40, 'white');	
			
			//Add Slice with Cell Noise and Signal areas on it
			if (debug_switch) print("[Debug Log]", "\nAdding Selections Slice");
			selectImage(window_MaxIP);
			run("Images to Stack", "name=Stack title=[] use");
			setSlice(1);
			run("Add Slice");
			run("Select All");
			setColor(0);
			fill;
			
			//Fill in Noise
			run("Select None");
			//setBatchMode('show');
			if (filter == true && x_values_high.length > 0) {
				roiManager("Select", newArray(0,6)); //Background 
				roiManager("AND");
				run("Make Inverse");
				roiManager("Add");
				SNR_drawHash(20, roiManager("Count") - 1);
				roiManager("Select", newArray(0,6)); //Background 
				roiManager("AND");
				//run("Make Inverse");
				if (selectionType() != -1) {
					run("Enlarge...", "enlarge=-0.214 micron");
					run("Enlarge...", "enlarge=0.214 micron");
					run("Enlarge...", "enlarge=0.107 micron");
					setColor(85);
					fill();
					run("Enlarge...", "enlarge=-0.107 micron");
					setColor(0);
					fill();
					run("Select None");
				}
				roiManager("Select", newArray(0,2,4,5)); //Noise, inverse of regular signal and bright signal
				roiManager("AND");
				setColor(85);
				fill();
				run("Select None");
				roiManager("Select", newArray(0,1)); //Regular Signal
				roiManager("AND");
				setColor(170);
				fill();
				run("Select None");
				roiManager("Select", newArray(0,3)); //Bright Signal
				roiManager("AND");
				setColor(255);
				fill();
				setForegroundColor(5, 5, 5);
				run("Draw", "slice");
				run("Enlarge...", "enlarge=0.107 micron");
				setForegroundColor(255, 255, 255);
				run("Draw", "slice");
				if (expansion_method != "Peaks") {
					for (q = 0; q < x_values.length && q < 10000; q++) {
						found = false;
						for (p = 0; p < low_counter.length; p++) {
							if (q == low_counter[p]) found = true;
						}
						if (found == false) setPixel(x_values[q], y_values[q], 200);
					}
				}
				setForegroundColor(0, 0, 0);
				drawString("Selection Bounds\nMaxima: " + maxima + "\nRegular Spots: " + spot_count + "\nFalse Spots Removed: " + filtered_spots + "\nBright Spots: " + x_values_high.length, 10, 40, 'white');
			}
			else {
				roiManager("Select", newArray(0,4)); //Background 
				roiManager("AND");
				run("Make Inverse");
				roiManager("Add");
				SNR_drawHash(20, roiManager("Count") - 1);
				roiManager("Select", newArray(0,4)); //Background 
				roiManager("AND");
				//run("Make Inverse");
				if (selectionType() != -1) {
					run("Enlarge...", "enlarge=-0.214 micron");
					run("Enlarge...", "enlarge=0.214 micron");
					run("Enlarge...", "enlarge=0.107 micron");
					setColor(85);
					fill();
					run("Enlarge...", "enlarge=-0.107 micron");
					setColor(0);
					fill();
					run("Select None");
				}
				roiManager("Select", newArray(0,2,3)); //Noise
				roiManager("AND");
				setColor(128);
				fill();
				run("Select None");
				roiManager("Select", 1); //Signal
				setColor(255);
				fill();
				if (expansion_method != "Peaks") {
					for (q = 0; q < x_values.length && q < 10000; q++) {
						setPixel(x_values[q], y_values[q], 200);
					}
				}
				drawString("Selection Bounds\nMaxima: " + maxima + "\nSpots: " + spot_count + "\nFalse Spots Removed: " + filtered_spots, 10, 40, 'white');
			}
			//setBatchMode('hide');
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
			if (debug_switch) print("[Debug Log]", "\nSaving debug image");
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

function SNR_drawHash(space, roi) {
	if (debug_switch) print("[Debug Log]", "\nDrawing hash marks\n");
	if (enable_hash == true) {
		roiManager("Select", roi);
		getSelectionBounds(x, y, draw_width, draw_height);
		setColor(170);
		start = roiManager("Count");
		inc = space*1.414213562;
		for (n = 0; n*inc < draw_width+draw_height; n++) {
			drawLine(x-draw_height+n*inc, y+draw_height, x+n*inc, y);
			if (debug_switch) print("[Debug Log]", ".");
		}
	}
	run("Select None");
}

function SNR_background(choice) {
	if (choice == 1) SNR_background1();
	else if (choice == 2) SNR_background2();
	else if (choice == 3) SNR_background3();
	else if (choice == 4) SNR_background4();
	else exit("Background Choice Error");
}

function SNR_background1() { //Measures background, inverse of noise in median image
	if (debug_switch) print("[Debug Log]", "\nMeasuring Background - Normal");
	selectImage(window_Median);
	run("Duplicate...", " ");
	run("Enhance Contrast", "saturated=0.01");
	run("8-bit");
	run("Select None");
	roiManager("Select", 0);
	run("Auto Local Threshold", "method=Phansalkar radius=100 parameter_1=0 parameter_2=0 white"); //Local Threshold Background
	run("Create Selection");
	if (selectionType() != -1) {
		run("Enlarge...", "enlarge=-0.214 micron");
		run("Enlarge...", "enlarge=1.821 micron");
		run("Make Inverse");
		roiManager("Add");
	}
	else {
		makeRectangle(0, 0, 2, 2);
		roiManager("Add");
	}
	close();
	selectImage(window_Median);
	roiManager("Select", newArray(0, roiManager("Count") - 1));
	roiManager("AND");
	run("Measure");
	run("Select None"); //Don't forget to set the File name and description in results
} //End of Function

function SNR_background2() { //Peak histogram
	if (debug_switch) print("[Debug Log]", "\nMeasuring Background - Peak");
	selectImage(window_Median);
	run("Duplicate...", " ");
	run("Select None");
	roiManager("Select", 0);
	getMinAndMax(min, max);
	values = newArray();
	counts = newArray();
	max_v = 0;
	max_c = 0;
	getHistogram(values, counts, 64, min, max);
	for (p = 0; p < values.length/2; p++) {
		//print("Current Max: " + max_v);
		//print("Value/Count: " + values[p] + "/" + counts[p]);
		if (max_c < counts[p]) {
			max_v = values[p];
			max_c = counts[p];
		}
	}
	setThreshold(0, max_v);
	run("Create Selection");
	if (selectionType() != -1) {
		run("Enlarge...", "enlarge=0.214 micron");
		run("Enlarge...", "enlarge=-0.214 micron");
		roiManager("Add");
	}
	else {
		makeRectangle(0, 0, 2, 2);
		roiManager("Add");
	}
	close();
	selectImage(window_Median);
	roiManager("Select", newArray(0, roiManager("Count") - 1));
	roiManager("AND");
	run("Measure");
	run("Select None");
}

function SNR_background3() { //Gaussian Fit Peak
	if (debug_switch) print("[Debug Log]", "\nMeasuring Background - Gaussian");
	selectImage(window_Median);
	run("Duplicate...", " ");
	run("Select None");
	roiManager("Select", 0);
	getMinAndMax(min, max);
	values = newArray();
	counts = newArray();
	getHistogram(values, counts, 128, min, max);
	Fit.doFit(12, values, counts);
	//Fit.plot;
	setThreshold(0, Fit.p(2));
	run("Create Selection");
	if (selectionType() != -1) {
		run("Enlarge...", "enlarge=0.214 micron");
		run("Enlarge...", "enlarge=-0.214 micron");
		roiManager("Add");
	}
	else {
		makeRectangle(0, 0, 2, 2);
		roiManager("Add");
	}
	close();
	selectImage(window_Median);
	roiManager("Select", newArray(0, roiManager("Count") - 1));
	roiManager("AND");
	run("Measure");
	run("Select None");
}

function SNR_background4() { //Bottom 10%
	if (debug_switch) print("[Debug Log]", "\nMeasuring Background - 10%");
	selectImage(window_Median);
	run("Duplicate...", " ");
	roiManager("Select", 0);
	getMinAndMax(min, max);
	values = newArray();
	counts = newArray();
	max_v = 0;
	max_c = 0;
	getHistogram(values, counts, 128, min, max);
	for (p = 0; p < counts.length; p++) max_c += counts[p];
	max_c = max_c * 0.1;
	for (p = 0; max_c > 0; p++) max_c = max_c - counts[p];
	setThreshold(0, values[p]);
	run("Create Selection");
	if (selectionType() != -1) {
		run("Enlarge...", "enlarge=0.214 micron");
		run("Enlarge...", "enlarge=-0.214 micron");
		roiManager("Add");
	}
	else {
		makeRectangle(0, 0, 2, 2);
		roiManager("Add");
	}
	close();
	selectImage(window_Median);
	roiManager("Select", newArray(0, roiManager("Count") - 1));
	roiManager("AND");
	run("Measure");
	run("Select None");
}

function SNR_noise() { //Measures Cell Noise
	if (debug_switch) print("[Debug Log]", "\nMeasuring Noise");
	check = 0;
	do {
		temp = false;
		check++;
		selectImage(window_Median);
		run("Duplicate...", " ");
		run("Enhance Contrast", "saturated=0.01");
		run("8-bit");
		run("Select None");
		roiManager("Select", 0);
		if (noise_method == "Normal") {
			run("Auto Local Threshold", "method=Phansalkar radius=" + 15*check + " parameter_1=0 parameter_2=0 white"); //Local Threshold cell noise
			run("Create Selection"); //Create selection 2
			run("Enlarge...", "enlarge=-0.214 micron"); //Remove very small selections
			run("Enlarge...", "enlarge=1.821 micron"); //Expand Cell noise boundary; Needed for exceptional images
			if (selectionType() != -1) {
				roiManager("Add");
			}
			else {
				makeRectangle(0, 0, 2, 2);
				roiManager("Add");
			}
			close();
			selectImage(window_Median);
			roiManager("Select", newArray(0, roiManager("Count") - 1)); //Select Cell Noise
			roiManager("AND"); //Select regions of Cell Noise
		}
		else {
			roiManager("Add");
			close();
			selectImage(window_Median);
			roiManager("Select", newArray(0, roiManager("Count") - 1)); //Select Cell Noise
			roiManager("AND"); //Select regions of Cell Noise
		}
		
		run("Measure");
		
		if (noise_method == "Normal" && getResult("Area", nResults - 1) >= (width/pixel_width)*(height/pixel_height)-1 && check < 7) {
			roiManager("Deselect");
			roiManager("Select", roiManager("Count") - 1);
			roiManager("Delete");
			IJ.deleteRows(nResults-1, nResults-1);
			temp = true;
		}
	} while (noise_method == "Normal" && temp == true && check < 7);
	/*if (check > 1) {
	setBatchMode(false);
	exit("Noise Selection required " + check + " passes");
	}*/
	run("Select None"); //Don't forget to set the File name and description in results and clear ROI manager
} //End of Noise function

function SNR_median(array) {
	temparr = newArray(); //temporary array
	temparr = Array.copy(array); //temp array stores mean_intensity values
	Array.sort(temparr);
	if (temparr.length%2 == 0) { //If even
		temp = temparr.length/2 - 1;
		return (temparr[temp] + temparr[temp+1])/2;
	}
	else { //Odd
		return temparr[floor(temparr.length/2)];
	}
}

function SNR_signal(roi) { //Measures Signal, ensure dots is in ROI manager, position 0
	if (debug_switch) print("[Debug Log]", "\nMeasuring Signal - ROI: " + roi);
	if (expansion_method != "Gaussian") {
		selectImage(window_MaxIP);
		roiManager("Select", newArray(0, roi));
		roiManager("AND");
		run("Measure");
		run("Select None");
	}
	else { //Gaussian
		if (roi == 1) {
			Array.getStatistics(amplitude, s_min, s_max, s_mean, s_stdDev);
			s_med = SNR_median(amplitude);
		}
		else if (roi == 3) {
			Array.getStatistics(amplitude_high, s_min, s_max, s_mean, s_stdDev);
			s_med = SNR_median(amplitude_high);
		}
		else exit("Gaussian ROI is incorrect, ROI: " + roi);
		setResult("Area", nResults - 1, area_cutoff + 1);
		setResult("Mean", nResults - 1, s_mean);
		setResult("StdDev", nResults - 1, s_stdDev);
		setResult("Min", nResults - 1, s_min);
		setResult("Max", nResults - 1, s_max);
		setResult("Median", nResults - 1, s_med);
	}
} //End of signal function

function SNR_dots(xi, yi, window) { //Searches N, S, E, W and then draws an ellipse on mask image
	selectImage(window_MaxIP);
	cardinal = newArray(1, 1, 1, 1); //Array for directions
	cap = 0;
	
	//North point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi, yi - n)); //Add pixel value
	cardinal[0] = SNR_basic_expand(pixel, 1);
	
	//East point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi + n, yi)); //Add pixel value
	cardinal[1] = SNR_basic_expand(pixel, 1);
	
	//South point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi, yi + n)); //Add pixel value
	cardinal[2] = SNR_basic_expand(pixel, 1);
	
	//West point
	pixel = newArray();
	for (n = 0; n <= np_radii; n++) pixel = Array.concat(pixel, getPixel(xi - n, yi)); //Add pixel value
	cardinal[3] = SNR_basic_expand(pixel, 1);
	
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

function SNR_peak(xi, yi, window) {
	cardinal = newArray(0, 0, 0, 0);
	selectImage(window);
	makePoint(xi, yi);
	fill;
	return cardinal;
}

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
	cardinal = newArray(0, 0, 0, 0, 0, 0, 0, 0, 0);
	amp = 0;
	amp_div = 0;
	result = newArray(0, 0);
	pixel = newArray();
	cap = 0;
	//print(xi, yi);
	//Y-axis
	pixel = SNR_getline(xi, yi, 0, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[0] = result[0] - result[1]*gauss_d;
	cardinal[4] = result[0] + result[1]*gauss_d;
	if (result[2] != 0){
		amp += result[2];
		amp_div++;
	}
	
	//NW to SE
	pixel = SNR_getline(xi, yi, 1, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[7] = result[0] - result[1]*gauss_d;
	cardinal[3] = result[0] + result[1]*gauss_d;
	if (result[2] != 0){
		amp += result[2];
		amp_div++;
	}
	
	//X-axis
	pixel = SNR_getline(xi, yi, 2, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[6] = result[0] - result[1]*gauss_d;
	cardinal[2] = result[0] + result[1]*gauss_d;
	if (result[2] != 0){
		amp += result[2];
		amp_div++;
	}
	
	//SW to NE
	pixel = SNR_getline(xi, yi, 3, np_radii);
	result = SNR_gauss_expand(pixel);
	cardinal[5] = result[0] - result[1]*gauss_d;
	cardinal[1] = result[0] + result[1]*gauss_d;
	if (result[2] != 0){
		amp += result[2];
		amp_div++;
	}
	
	if (amp > 0) {
		amp /= amp_div;
		cardinal[8] = amp;
	}
	else cardinal[8] = 0;
	
	//Array.print(Array.concat(xi, yi, result[2], cardinal));
	
	for (i = 0; i < cardinal.length; i++) {
		if (cardinal[i] > 5) cap ++;
	}
	/*if (debug_switch) {
	print("(" + xi + "," + yi + ") bounding:");
	Array.print(cardinal); //debug
	}*/
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

function SNR_maximasearch() { //Searches until the slope of the spot count levels out
	if (debug_switch) print("[Debug Log]", "\nMaxima Search");
	maxima = maxima_start;
	slope = newArray();
	slope_second = newArray();
	slope_second_avg = 0;
	run("Clear Results");
	//Initialize Maxima Results
	selectImage(window_Subtract);
	getMinAndMax(min, max);
	roiManager("Select", 0);
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	maxima_inc = (max-min)/maxima_factor; //Set maxima increment to 100th of the image range
	if (maxima_inc < 10) maxima_inc = 10;
	//print("Maxima Increment: " + maxima_inc);
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
	n = 0;
	do { //Loop until the slope of the count levels out
		n++;
		//Get the next Spot Count
		selectImage(window_Subtract);
		roiManager("Select", 0);
		run("Find Maxima...", "noise=" + maxima + " output=Count");
		setResult("Maxima", nResults - 1, maxima);
		temp_count = getResult("Count", nResults - 1);
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
		/*if (debug_switch) {
		print("\nSlope");
		Array.print(slope);
		print("Slope_Second");
		Array.print(slope_second);
		print("slope_second_avg: " + slope_second_avg);
		}*/
	} while (slope_second_avg > pow(tolerance_maxima, 2) && temp_count > 1 && n < maxima_factor)  //Keep going as long as the average second_slope is greater than 4 (default)
	maxima -= slope.length * 0.5 * maxima_inc; //Once the condition has been met drop maxima back 50% of increment
	updateResults();
	
	if (rsquare == true) {
		for (n = maxima + slope.length * 0.5 * maxima_inc; n < maxima + maxima - maxima_start + 10 && temp_count > 1; n += maxima_inc) { //Continue measuring spots
			selectImage(window_Subtract);
			roiManager("Select", 0);
			run("Find Maxima...", "noise=" + n + " output=Count");
			setResult("Maxima", nResults - 1, n);
			temp_count = getResult("Count", nResults - 1);
			updateResults();
		}
		if (tolerance_maxima > 9) tolerance_maxima = 0.99;
		else tolerance_maxima = 0.9 + (tolerance_maxima/100); //0.95 default
		xvalues = newArray();
		yvalues = newArray();
		for (n = 0; n < nResults; n++) { //Add all Maxima and Count values to an array
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
	
	if (plot == true) { //Create plots for maxima results
		xvalues = newArray();
		yvalues = newArray();
		index = -1;
		for (n = 0; n < nResults; n++) { //Add Maxima and Count values to arrays
			xvalues = Array.concat(xvalues, getResult("Maxima", n));
			yvalues = Array.concat(yvalues, getResult("Count", n));
			if (xvalues[n] == maxima) index = n;
		}
		Plot.create("Plot", "Maxima", "Count", xvalues, yvalues); //Make plot
		Plot.drawLine(maxima, yvalues[yvalues.length - 1], maxima, yvalues[0]); //Draw vertical line at maxima
		Plot.show();
		selectWindow("Plot");
		saveAs("PNG", outDir + "Plots" + File.separator + stripath); //Save plot
		close();
	}
	
	return maxima;
}

function SNR_linearize(xvalues, yvalues) { //Returns an array with locations of segments with > 0.95 rsquared values fitting a linear regression formula
	segments = newArray(0, 0); //Initialize array
	p = 2;
	while (segments[segments.length - 1] < xvalues.length) { //Keep going until you hit the end
		//if (debug_switch) print("Testing " + segments[segments.length - 1] + " to " + p); //Debug
		do { //From the last entry until the rsquared value drops below the tolerance
			temp_x = Array.slice(xvalues, segments[segments.length - 1], p);
			temp_y = Array.slice(yvalues, segments[segments.length - 1], p);
			Fit.doFit(0, temp_x, temp_y);
			p += 1;
		} while (Fit.rSquared > tolerance_maxima && p < xvalues.length - 1);
		//if (debug_switch) Fit.plot;
		//if (debug_switch) setBatchMode('show'); //Debug
		segments = Array.concat(segments, p-2);
		p = segments[segments.length - 1] + 2;
	}
	//if (debug_switch) Array.print(segments);
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

function SNR_stddev(a, b) {
	return sqrt(pow(a, 2) + pow(b, 2));
}

function SNR_results(boo) { //Calculates base SNR and other base values
	if (debug_switch) print("[Debug Log]", "\nResults");
	//boo = 1: Results
	//boo = 2: Bright
	//boo = 3: Bright_Null
	warnings = 0;
	signal = 0;
	signal_stddev = 0;
	noise = 0;
	noise_stddev = 0;
	SNR = 0;
	cv = 0;
	signoi = 0;
	signoi_stddev = 0;
	pass = "Fail";
	
	signal_bright = 0;
	signal_bright_stddev = 0;
	SNR_bright = 0;
	signoi_bright = 0;
	signoi_bright_stddev = 0;
	pass_bright = "NA";
	n = 3;
	if (boo == 2) { //Bright Results
		n = 4;
		signal_bright = getResult("Median", nResults - n + 1) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
		signal_bright_stddev = SNR_stddev(getResult("StdDev", nResults - n + 1), getResult("StdDev", nResults - 1)); //STDDEV
		noise = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
		noise_stddev = SNR_stddev(getResult("StdDev", nResults - 2), getResult("StdDev", nResults - 1));
		SNR_bright = signal_bright / noise; //SNR = (Signal Median - Back Median) / (Noise Median - Back Median)
		signoi_bright = getResult("Median", nResults - n + 1) - getResult("Median", nResults - 2);
		signoi_bright_stddev = SNR_stddev(getResult("StdDev", nResults - n + 1), getResult("StdDev", nResults - 2));
		if (expansion_method == "Gaussian") {
			signal_bright = getResult("Median", nResults - n + 1); //Rel Signal = Signal Median
			signal_bright_stddev = getResult("StdDev", nResults - n + 1); //STDDEV
		}
		if (SNR_bright > pass_snr && signoi_bright > pass_signoi) pass_bright = "Pass";
		else pass_bright = "Fail";
	}
	
	signal = getResult("Median", nResults - n) - getResult("Median", nResults - 1); //Rel Signal = Signal Median - Back Median
	signal_stddev = SNR_stddev(getResult("StdDev", nResults - n), getResult("StdDev", nResults - 1));
	noise = getResult("Median", nResults - 2) - getResult("Median", nResults - 1); //Rel Noise = Noise Median - Back Median
	noise_stddev = SNR_stddev(getResult("StdDev", nResults - 2), getResult("StdDev", nResults - 1));
	SNR = signal / noise; //SNR = (Signal Median - Back Median) / (Noise Median - Back Median)
	cv = getResult("StdDev", nResults - n) / getResult("Mean", nResults - n); //Coefficient of Variation - Signal
	signoi = getResult("Median", nResults - n) - getResult("Median", nResults - 2);
	signoi_stddev = SNR_stddev(getResult("StdDev", nResults - n), getResult("StdDev", nResults - 2));
	if (expansion_method == "Gaussian") {
		signal = getResult("Median", nResults - n); //Rel Signal = Signal Median
		signal_stddev = getResult("StdDev", nResults - n);
	}
	if (SNR > pass_snr && signoi > pass_signoi) pass = "Pass";
	
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
		signal = 0;
		signal_stddev = 0;
		SNR = 0;
		signoi = 0;
		signoi_stddev = 0;
		warnings += 8;
		pass = "Fail";
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
	
	print(pass + " S-N = " + signoi + " SNR = " + SNR);
	if (boo == 2) print("Bright: " + pass_bright + " S-N = " + signoi_bright + " SNR = " + SNR_bright);
	
	return newArray(SNR, SNR_bright, signal, signal_stddev, noise, noise_stddev, signal_bright, signal_bright_stddev, signoi, signoi_stddev, signoi_bright, signoi_bright_stddev);
}

function SNR_save_results(boo) { //Save Results to Raw and Condensed Tables, Save individual results
	if (debug_switch) print("[Debug Log]", "\nSaving Results");
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
		
		line += "," + pass;
		line += "," + signoi;
		line += "," + signoi_stddev;
		line += "," + SNR;
		line += "," + signal;
		line += "," + signal_stddev;
		line += "," + noise;
		line += "," + noise_stddev;
		line += "," + spot_count;
		line += "," + filtered_spots;
		line += "," + maxima;
		line += ", " + expansion_method;
		line += "," + warnings;
		print("[SNR]", line);
		comb = line;
		line = "";
	}
	
	if (boo == 2) { //Print Bright line of Raw
		line += getResultString("Area", nResults - n + 1);
		line += "," + getResultString("Mean", nResults - n + 1);
		line += "," + getResultString("StdDev", nResults - n + 1);
		line += "," + getResultString("Min", nResults - n + 1);
		line += "," + getResultString("Max", nResults - n + 1);
		line += "," + getResultString("Median", nResults - n + 1);
		line += "," + getResultString("File", nResults - n + 1);
		line += "," + getResultString("Description", nResults - n + 1);
		line += "," + getResultString("Coefficient of Variation", nResults - n + 1);
		
		line += "," + pass_bright;
		line += "," + signoi_bright;
		line += "," + signoi_bright_stddev;
		line += "," + SNR_bright;
		line += "," + signal_bright;
		line += "," + signal_bright_stddev;
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
		line += "," + pass;
		if (boo != 1) line += "," + pass_bright;
		line += "," + signoi;
		line += "," + signoi_stddev;
		if (boo != 1) line += "," + signoi_bright;
		if (boo != 1) line += "," + signoi_bright_stddev;
		line += "," + SNR;
		if (boo != 1) line += "," + SNR_bright;
		line += "," + signal;
		line += "," + signal_stddev;
		if (boo != 1) line += "," + signal_bright;
		if (boo != 1) line += "," + signal_bright_stddev;
		line += "," + noise;
		line += "," + noise_stddev;
		line += "," + spot_count;
		line += "," + filtered_spots;
		line += "," + maxima;
		line += ", " + expansion_method;
		line += "," + warnings;
		print("[Condense]", line);
	}
	
	//Save Info
	File.saveString(line, savedataDir + stripath + "_Condense.csv");
	File.saveString(comb, savedataDir + stripath + "_Raw.csv");
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

function SNR_spelt_int(int) {
	sign = false;
	if (int < 0) {
		sign = true;
		int *= -1;
	}
	
	if (int < 10) {
		if (floor(int) == 0) result =  "Zero";
		else if (floor(int) == 1) result = "One";
		else if (floor(int) == 2) result = "Two";
		else if (floor(int) == 3) result = "Three";
		else if (floor(int) == 4) result = "Four";
		else if (floor(int) == 5) result = "Five";
		else if (floor(int) == 6) result = "Six";
		else if (floor(int) == 7) result = "Seven";
		else if (floor(int) == 8) result = "Eight";
		else if (floor(int) == 9) result = "Nine";
		if (sign == false) return result;
		else return "Negative " + result;
	}
	else if (int < 20) {
		if (floor(int) == 10) result = "Ten";
		else if (floor(int) == 11) result = "Eleven";
		else if (floor(int) == 12) result = "Twelve";
		else if (floor(int) == 13) result = "Thirteen";
		else if (floor(int) == 14) result = "Fourteen";
		else if (floor(int) == 15) result = "Fifteen";
		else if (floor(int) == 16) result = "Sixteen";
		else if (floor(int) == 17) result = "Seventeen";
		else if (floor(int) == 18) result = "Eighteen";
		else if (floor(int) == 19) result = "Nineteen";
		if (sign == false) return result;
		else return "Negative " + result;
	}
	else if (int < 100) {
		if (floor(int) == 20) result = "Twenty";
		else if (int > 20 && int < 30) result = "Twenty " + SNR_spelt_int(int%10);
		else if (floor(int) == 30) result = "Thirty";
		else if (int > 30 && int < 40) result = "Thirty " + SNR_spelt_int(int%10);
		else if (floor(int) == 40) result = "Fourty";
		else if (int > 40 && int < 50) result = "Fourty " + SNR_spelt_int(int%10);
		else if (floor(int) == 50) result = "Fifty";
		else if (int > 50 && int < 60) result = "Fifty " + SNR_spelt_int(int%10);
		else if (floor(int) == 60) result = "Sixty";
		else if (int > 60 && int < 70) result = "Sixty " + SNR_spelt_int(int%10);
		else if (floor(int) == 70) result = "Seventy";
		else if (int > 70 && int < 80) result = "Seventy " + SNR_spelt_int(int%10);
		else if (floor(int) == 80) result = "Eighty";
		else if (int > 80 && int < 90) result = "Eighty " + SNR_spelt_int(int%10);
		else if (floor(int) == 90) result = "Ninety";
		else if (int > 90 && int < 100) result = "Ninety " + SNR_spelt_int(int%10);
		if (sign == false) return result;
		else return "Negative " + result;
	}
	else if (int < 1000) {
		result = "" + SNR_spelt_int(int/100) + " Hundred";
		if (int%100 != 0) result += " and " + SNR_spelt_int(int%100);
		if (sign == false) return result;
		else return "Negative " + result;
	}
	else if (int < 1000000) {
		result = "" + SNR_spelt_int(int/1000) + " Thousand";
		if (int%1000 != 0) result += ", " + SNR_spelt_int(int%1000);
		if (sign == false) return result;
		else return "Negative " + result;
	}
	else if (int < 1000000000) {
		result = "" + SNR_spelt_int(int/1000000) + " Million";
		if (int%1000000 != 0) result += ", " + SNR_spelt_int(int%1000000);
		if (sign == false) return result;
		else return "Negative " + result;
	}
	else if (int < 1000000000000) {
		result = "" + SNR_spelt_int(int/1000000000) + " Billion";
		if (int%1000000000 != 0) result += ", " + SNR_spelt_int(int%1000000000);
		if (sign == false) return result;
		else return "Negative " + result;
	}
	else {
		rng = random;
		if (rng > 0.66) result = "\"A Lot\"";
		else if (rng < 0.33) result = "\"A Bunch\"";
		else result = "\"Way too much\""
		if (sign == false) return result;
		else return "Negative " + result;
	}
}