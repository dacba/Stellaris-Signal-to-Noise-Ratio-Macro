
macro "Calculate Signal to Noise Ratio...[c]" {
/*
This macro opens a directory and does an in depth analysis of spots
Based off of "TrevorsMeasure" or "Measure Dots..."
Uses Find Maxima to find spots and expand the points to a selection used for spot analysis
Use the Default threshold to determine cell noise and background values

Tested on ImageJ version 1.49m
*/

//Default Variables
tolerance_bounding = 0.1; //Tolerance for ellipse bounding. Higher means tighter ellipsies 
tolerance_upward = 0.8; //Tolerates upward movement (0 means any upward movement will be tolerated, 1 means tolerance will be the same as downward movement)
maxima = 50;
poly = false;
tolerance_maxima = 1;
sum_intensity = false;


//Dialog
Dialog.create("Spot Processer");

Dialog.addMessage("Please enter the bounding tolerance, upward tolerance and Maxima Tolerance");
Dialog.addSlider("Bounding Tolerance:", 0, 1, tolerance_bounding);
Dialog.addSlider("Upward Tolerance:", 0, 1, tolerance_upward);
Dialog.addSlider("Maxmia:", 0, 200, maxima);
Dialog.addSlider("Maxmia Tolerance:", 1, 50, tolerance_maxima);
Dialog.addCheckbox("Polygon spot creation (Slower)", false);
Dialog.addCheckbox("Sum Intensity(Slower)", false);
Dialog.show();

//Retrieve Choices
tolerance_bounding = Dialog.getNumber();
tolerance_upward = Dialog.getNumber();
maxima = Dialog.getNumber();
tolerance_maxima = Dialog.getNumber();
poly = Dialog.getCheckbox();
sum_intensity = Dialog.getCheckbox();

//Warn if Choices are outside of recommended range
if (tolerance_bounding > 0.9 || tolerance_bounding > 0.7 || tolerance_upward < 0.5 || tolerance_maxima > 10 || maxima > 70) {
	Dialog.create("Warning");
	Dialog.addMessage("One or more of your vairables are outside of the recommended ranges.\nPlease refer to the recommended ranges below.");
	Dialog.addMessage("Bounding Tolerance: 0.7 - 0.9  (" + tolerance_bounding + ")\nUpward Tolerance: 0.5 - 1.0  (" + tolerance_upward + ")\nMaxima: 0 - 50  (" + maxima + ")\nMaxima Tolerance: 1 - 10  (" + tolerance_maxima + ")");
	Dialog.addMessage("If you would like to continue using these variables press \"OK\" to continue\nBe sure to check the merged tif files to ensure the analysis was done correctly");
	Dialog.show();
	}


//Initialize
setBatchMode(true);
setOption("ShowRowNumbers", false);
run("Set Measurements...", "area mean standard min median redirect=None decimal=3");
run("Input/Output...", "jpeg=85 gif=-1 file=.csv save_column");
setFont("SansSerif", 22);
print("\\Clear");
run("Clear Results");

//Open Tables
run("Table...", "name=SNR width=400 height=200");
run("Table...", "name=Points width=400 height=200");
run("Table...", "name=Condense width=400 height=200");
//Initialize SNR table
if (poly == false ) print("[SNR]", "Bounding Tolerance: " + tolerance_bounding + " Upward Tolerance: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Ellipse");
else print("[SNR]", "Bounding Tolerance: " + tolerance_bounding + " Upward Tolerance: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Polygon");
print("[SNR]", "Area, Mean, StdDev, Min, Max, Median, File, Description, Mean StN Ratio, Median StN Ratio, Median Signal - Background, Median Noise - Background, Spots, Maxima, Warnings");
//Initialize Condensed Table
if (poly == false ) print("[Condense]", "Bounding Tolerance: " + tolerance_bounding + " Upward Tolerance: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Ellipse");
else print("[Condense]", "Bounding Tolerance: " + tolerance_bounding + " Upward Tolerance: " + tolerance_upward + " Maxima Tolerance: " + tolerance_maxima + " Polygon");
print("[Condense]", "File, Mean StN Ratio, Median StN Ratio, Median Signal - Background, Median Noise - Background, Spots, Maxima, Warnings");

if (sum_intensity == false) print("[Points]", "Peak Brightness");
else print("[Points]", "Sum Intensity");

//Create Directories
dir = getDirectory("Choose Directory containing .nd2 files"); //get directory
outDir = dir + "Out-SNRatio\\";
File.makeDirectory(outDir); //Create new out directory
File.makeDirectory(outDir + "\\Histograms\\"); //Create Histogram directory

//RUN IT!
SNRmain(dir, ""); 

//Save it!
selectWindow("SNR");
saveAs("Results", outDir + "Results_SNR.csv");
run("Close");
selectWindow("Points");
saveAs("Results", outDir + "Results_Points.csv");
run("Close");
selectWindow("Condense");
saveAs("Results", outDir + "Results_Condense.csv");
run("Close");

function SNRmain(dir, sub) {
	run("Bio-Formats Macro Extensions");
	list = getFileList(dir + sub);//get file list 
	n = 0;
	for (i=0;i<list.length; i++){ //for each file
		path = sub + list[i];
		if (endsWith(list[i], "/") && indexOf(path, "Out") == -1) {
			File.makeDirectory(outDir + path); //Recreate file system in output folder
			SNRmain(dir, path); //Recursive Step
			}
		else if (endsWith(list[i], ".nd2")) {
			strip = substring(list[i], 0, indexOf(list[i], ".nd2"));
			stripath = replace(substring(path, 0, indexOf(path, ".nd2")), "/", "_");
			run("Bio-Formats Importer", "open=[" + dir + path + "] autoscale color_mode=Grayscale view=Hyperstack");
			info = getImageInfo();
			if (indexOf(substring(info, indexOf(info, "Negate") - 6, indexOf(info, "Negate")), "DAPI") > -1) close(); //If DAPI, ignore
			else {
			//Initialize Image
			print("File: " + path);
			height = getHeight();
			width = getWidth();
			window_raw = getImageID();
			if (nSlices > 1) run("Z Project...", "projection=[Max Intensity]"); //Max intensity merge
			window_zstack = getImageID();
			selectImage(window_raw);
			run("Close");
			
			//Determine Maxima
			maxima = derivative();
			selectImage(window_zstack);
			run("Clear Results");
			if (sum_intensity == false) {
				run("Find Maxima...", "noise=" + maxima + " output=[Point Selection]");
				run("Measure");
				String.resetBuffer;
				String.append(path + ", ");
				for (n = 1; n < nResults; n++) String.append(getResult("Mean", n) + ", ");
				print("[Points]", String.buffer);
				}
			else {
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
				print("[Points]", String.buffer);
				}

			//Create signal mask image
			newImage("Signal", "8-bit white", width, height, 1); 
			window_signal = getImageID();
			setColor(0);
			seed = nResults;
			
			
			//Expand dots
			if (poly == false) { //Run the faster dots program
				for (q = 0; q < nResults && q < 2500; q++) {
					dots(round(getResult("X", q)), round(getResult("Y", q))); //Run dots with different x and y values
					}//End of dots loop
				}
			else { //Run the slower polygon program
				for (q = 0; q < nResults && q < 2500; q++) {
					crazypoly(round(getResult("X", q)), round(getResult("Y", q))); //Run dots with different x and y values
					}//End of dots loop
				}
			
			//Create Selection of signal
			print(nResults + " points processed");
			selectImage(window_signal);
			run("Create Selection");
			roiManager("Add"); //Create Signal selection
			run("Make Inverse"); //Make selection inverted
			roiManager("Add"); //Create Inverse Signal selection
			
			//Run signal
			selectImage(window_zstack);
			signal();
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Signal");
			updateResults();
			
			//Run Noise
			selectImage(window_zstack);
			noise(); 
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Cell Noise");
			updateResults();
			
			//Run Background
			selectImage(window_zstack);
			background();
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Background");
			updateResults();
			
			//Results
			results();
			
			//Save Images
			selectImage(window_zstack);
			run("Select None");
			run("Enhance Contrast", "saturated=0.01"); //Make it pretty
			selectImage(window_zstack);
			run("8-bit");
			drawString(path, 10, 40, 'white');
			selectImage(window_signal);
			run("Invert"); 
			drawString("Signal Mask", 10, 40, 'white');
			run("Images to Stack");
			setSlice(2);
			run("Add Slice");
			roiManager("Select", newArray(1,2));
			roiManager("AND");
			setColor(128);
			fill();
			run("Select None");
			roiManager("Select", 0);
			setColor(255);
			fill();
			drawString("Cell Noise", 10, 40, 'white');
			run("Select None");
			saveAs("tif", outDir + sub + strip + "_Merge.tif");
			
			run("Close All");
			roiManager("Deselect");
			roiManager("Delete");
			}} //end of else
		}//end of for loop
	}//end of function


function background() { //Measures background, the darkest part, where there are no cells
	run("Select None");
	setAutoThreshold("Default"); //Default is good for background (especially very dark cell noise)
	run("Create Selection");
	run("Measure");
	run("Histogram");
	saveAs("PNG", outDir + "\\Histograms\\" + stripath + "_Background.png");
	close();
	run("Select None"); //Don't forget to set the File name and description in results
	} //End of Function

function noise() { //Measures Cell Noise, ensure dots and inverse dots are in the ROI manager, positions 0 and 1 respectively
	run("Select None");
	setAutoThreshold("Default dark"); //Threshold cell noise
	run("Create Selection"); //Create selection 2
	run("Enlarge...", "enlarge=-1 pixel"); //Remove very small selections
	run("Enlarge...", "enlarge=11 pixel"); //Expand Cell noise boundary; Needed for exceptional images
	roiManager("Add");
	roiManager("Select", newArray(1,2));//Select Inverse dots and Cell Noise
	roiManager("AND"); //Select regions of Cell Noise and inverse of dots
	run("Measure");
	run("Histogram");
	saveAs("PNG", outDir + "\\Histograms\\" + stripath + "_Cell_Noise.png");
	close();
	run("Select None"); //Don't forget to set the File name and description in results and clear ROI manager
	}//End of Noise function

function signal() { //Measures Signal, ensure dots is in ROI manager, position 0
	run("Select None");
	roiManager("Select", 0);
	run("Measure");
	run("Histogram");
	saveAs("PNG", outDir + "\\Histograms\\" + stripath + "_Signal.png");
	close();
	run("Select None");
	} //End of signal function

function dots(xi, yi) { //Searches N, S, E, W and then draws an ellipse on mask image
	selectImage(window_zstack);
	bright = getPixel(xi,yi);
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance_bounding; r++); //Progress r until there is a drop in brightness (>10% default)
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright > tolerance_bounding || getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++); //Progress r until there is no change in brightness (<10% default)
	x2 = xi + r; //right
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance_bounding; r--);
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r - 1, yi)/bright > tolerance_bounding || getPixel(xi + r, yi)/bright - getPixel(xi + r - 1, yi)/bright < - tolerance_bounding * tolerance_upward) && r > -15; r--);
	x1 = xi + r; //left
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright > tolerance_bounding || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++);
	y2 = yi + r; //top
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance_bounding; r--);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r - 1)/bright > tolerance_bounding || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r - 1)/bright < - tolerance_bounding * tolerance_upward) && r > -15; r--);
	y1 = yi + r; //bottom
	
	w = x2-x1;
	h = y2-y1;
	
	selectImage(window_signal);
	fillOval(x1, y1, w, h);
	}//End of dot function

function crazypoly(xi, yi) { //Searches in eight cardinal directions and draws polygon on mask image
	selectImage(window_zstack);
	bright = getPixel(xi,yi);
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright > tolerance_bounding || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++); 
	north = yi + r; //North point
	
	for (r = 0; getPixel(xi + r, yi + r)/bright > 1 - tolerance_bounding; r++); 
	for (r = r; (getPixel(xi + r, yi + r)/bright - getPixel(xi + r + 1, yi + r + 1)/bright > tolerance_bounding || getPixel(xi + r, yi + r)/bright - getPixel(xi + r + 1, yi + r + 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++); 
	northeast = r; //Northeast point
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright > tolerance_bounding || getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++); 
	east = xi + r; //East point
	
	for (r = 0; getPixel(xi + r, yi - r)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi + r, yi - r)/bright - getPixel(xi + r + 1, yi - r - 1)/bright > tolerance_bounding || getPixel(xi + r, yi - r)/bright - getPixel(xi + r + 1, yi - r - 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++);
	southeast = r; //Southeast point
	
	for (r = 0; getPixel(xi, yi - r)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi, yi - r)/bright - getPixel(xi, yi - r - 1)/bright > tolerance_bounding || getPixel(xi, yi - r)/bright - getPixel(xi, yi - r - 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++);
	south = yi - r; //South Point
	
	for (r = 0; getPixel(xi - r, yi - r)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi - r, yi - r)/bright - getPixel(xi - r + 1, yi - r - 1)/bright > tolerance_bounding || getPixel(xi - r, yi - r)/bright - getPixel(xi - r + 1, yi - r - 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++);
	southwest = r; //Southwest point
	
	for (r = 0; getPixel(xi - r, yi)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi - r, yi)/bright - getPixel(xi - r - 1, yi)/bright > tolerance_bounding || getPixel(xi - r, yi)/bright - getPixel(xi - r - 1, yi)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++);
	west = xi - r; //West point
	
	for (r = 0; getPixel(xi - r, yi + r)/bright > 1 - tolerance_bounding; r++);
	for (r = r; (getPixel(xi - r, yi + r)/bright - getPixel(xi - r - 1, yi + r + 1)/bright > tolerance_bounding || getPixel(xi - r, yi + r)/bright - getPixel(xi - r - 1, yi + r + 1)/bright < - tolerance_bounding * tolerance_upward) && r < 15; r++);
	northwest = r; //Northwest point
	
	selectImage(window_signal);
	makePolygon(xi, north, xi + northeast, yi + northeast, east, yi, xi + southeast, yi - southeast, xi, south, xi - southwest, yi - southwest, west, yi, xi - northwest, yi + northwest);
	fill();
	}//End of crazy polygon function

function derivative() { //Searches upwards until spot count levels out
	run("Clear Results");
	maxima = 50;
	//Initialize Maxima Results
	run("Find Maxima...", "noise=" + maxima + " output=Count");
	setResult("Maxima", nResults - 1, maxima);
	updateResults();
	maxima += 5;
	do { //Loop until count levels out
		run("Find Maxima...", "noise=" + maxima + " output=Count");
		setResult("Maxima", nResults - 1, maxima);
		updateResults();
		maxima += 5;
		} while (getResult("Count", nResults - 2)/getResult("Count", nResults - 1) > 1 + (tolerance_maxima/100))
	run("Find Maxima...", "noise=" + maxima + " output=Count"); //Run one more time and make sure the spot count difference wasn't a one-time fluke
	setResult("Maxima", nResults - 1, maxima);
	updateResults();
	if (getResult("Count", nResults - 2)/getResult("Count", nResults - 1) > 1 + (tolerance_maxima/100));
	else { 
		maxima += 5;
		do { 
			run("Find Maxima...", "noise=" + maxima + " output=Count");
			setResult("Maxima", nResults - 1, maxima);
			updateResults();
			maxima += 5;
			} while (getResult("Count", nResults - 2)/getResult("Count", nResults - 1) > 1 + (tolerance_maxima/100))
		}
	return maxima;
	}

function results() {
	//Calculate signal to noise ratio
	signoimean = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1));
	signoimedian = (getResult("Median", nResults - 3) - getResult("Median", nResults - 1)) / (getResult("Median", nResults - 2) - getResult("Median", nResults - 1));
	sigrel = getResult("Median", nResults - 3) - getResult("Median", nResults - 1);
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1);
	if (getResult("Area", nResults - 3) >= getResult("Area", nResults - 2)) { //If signal area is greater than noise area
		signoimean = "inf";
		signoimedian = "inf";
		noirel = 0;
		}
	//Set results
	setResult("Mean StN Ratio", nResults - 3, signoimean);
	setResult("Median StN Ratio", nResults - 3, signoimedian);
	setResult("Median Signal - Background", nResults - 3, sigrel);
	setResult("Median Noise - Background", nResults - 3, noirel);
	setResult("Spots", nResults - 3, seed);
	setResult("Maxima", nResults - 3, maxima);
	//Set Warnings
	if (getResult("Spots", nResults - 3) < 100) setResult("Warnings", nResults - 3, "Low Spot Count");
	if (noirel == 0) setResult("Warnings", nResults - 3, "Signal Area >= Noise Area");
	updateResults();
	//String manipulation
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[SNR]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	
	//Save Condensed Results
	setResult("File", nResults, path);
	setResult("Mean StN Ratio", nResults - 1, signoimean);
	setResult("Median StN Ratio", nResults - 1, signoimedian);
	setResult("Median Signal - Background", nResults - 1, sigrel);
	setResult("Median Noise - Background", nResults - 1, noirel);
	setResult("Spots", nResults - 1, seed);
	setResult("Maxima", nResults - 1, maxima);
	if (getResult("Spots", nResults - 1) < 100) setResult("Warnings", nResults - 1, "Low Spot Count");
	if (noirel == 0) setResult("Warnings", nResults - 1, "Signal Area >= Noise Area");
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Condense]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	}

print("-- Done --");
showStatus("Finished.");
}//end of macro