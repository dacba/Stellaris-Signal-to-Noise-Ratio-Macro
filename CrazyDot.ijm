macro "Calculate Signal to Noise Ratio...[c]" {
/*
This macro opens a directory and does an in depth analysis of spots
Based off of "TrevorsMeasure" or "Measure Dots..."
Uses Find Maxima, noise 125, to find spots and expand the points to a selection used for spot analysis
Use the Li threshold to determine cell noise and background values

Tested on Fiji/ImageJ version 1.49b
*/

//Default Variables
tolerance = 0.1; //Tolerance for ellipse bounding. Higher means tighter ellipsies 
tolerancemultiplier = 0.8; //Tolerates upward movement (0 means any upward movement will be tolerated, 1 means tolerance will be the same as downward movement)
maxima = 125;
poly = false;
zscore = -0.5; //Cutoffs, -3.0=0.1%, -2.0=2.3%, -1.5=7%, -1.0=15.9%, 0.0=50%
//zscore is used in finding the maxima

//Dialog
Dialog.create("Spot Processer");

Dialog.addMessage("Please enter the bounding tolerance, upward tolerance, and Z-score cutoff");
Dialog.addString("Bounding Tolerance:", tolerance);
Dialog.addString("Upward Tolerance:", tolerancemultiplier);
Dialog.addString("Z-Score:", zscore);
Dialog.addMessage("Bounding Tolerance: (0-1) Determines the cutoff point for spot expansion, lower means more strict(smaller area selected)\nUpward Tolerance: (0-1) Determines the tolerance for upward movement during spot expansion; 0 means any upward movement is tolerated, 1 means upward movement is tolerated the same as downward.\nZ-Score: (-3.0 - 3.0) Determines the cutoff for local maxima selection, lower means less spots");
Dialog.addCheckbox("Polygon spot creation (Slower, but more accurate)", false);
Dialog.show();

//Retrieve Choices
tolerance = Dialog.getString();
tolerancemultiplier = Dialog.getString();
zscore = Dialog.getString();
poly = Dialog.getCheckbox();


//Initialize
setBatchMode(true);
setOption("ShowRowNumbers", false);
run("Set Measurements...", "area mean standard min median redirect=None decimal=3");
run("Input/Output...", "jpeg=85 gif=-1 file=.csv save_column");
setFont("SansSerif", 22);
print("\\Clear"); //Clear log
run("Clear Results");
run("Table...", "name=Final width=800 height=400");
if (poly == false ) print("[Final]", "Bounding Tolerance: " + tolerance + " Upward Tolerance: " + tolerancemultiplier + " Z-Score: " + zscore + " Ellipse");
else print("[Final]", "Bounding Tolerance: " + tolerance + " Upward Tolerance: " + tolerancemultiplier + " Z-Score: " + zscore + " Polygon");
print("[Final]", "Area, Mean, StdDev, Min, Max, Median, File, Description, Mean StN Ratio, Median StN Ratio, Median Signal - Background, Median Noise - Background, Spots, Maxima, Warnings");


dir = getDirectory("Choose Directory containing .nd2 files"); //get directory
outDir = dir + "Out-SNRatio\\";
File.makeDirectory(outDir); //Create new out directory
File.makeDirectory(outDir + "\\Histograms\\"); //Create Histogram directory

process(dir, ""); //RUN IT!

//Save it!
selectWindow("Final");
saveAs("Results", outDir + "Results.csv");
run("Close");

function process(dir, sub) {
	run("Bio-Formats Macro Extensions");
	list = getFileList(dir + sub);//get file list 
	n = 0;
	for (i=0;i<list.length; i++){ //for each file
		path = sub + list[i];
		if (endsWith(list[i], "/") && indexOf(path, "Out") == -1) {
			File.makeDirectory(outDir + path); //Recreate file system in output folder
			process(dir, path); //Recursive Step
			}
		else if (endsWith(list[i], ".nd2")) {
			strip = substring(list[i], 0, indexOf(list[i], ".nd2"));
			stripath = replace(substring(path, 0, indexOf(path, ".nd2")), "/", "_");
			run("Bio-Formats Importer", "open=[" + dir + path + "] autoscale color_mode=Grayscale view=Hyperstack");
			info = getImageInfo();
			if (indexOf(substring(info, indexOf(info, "Negate") - 6, indexOf(info, "Negate")), "DAPI") > -1) close();
			else {
			print("File: " + path);
			height = getHeight();
			width = getWidth();
			if (nSlices > 1) run("Z Project...", "projection=[Max Intensity]"); //Max intensity merge
			maxima = derivative();
			selectWindow("MAX_" + path);
			run("Find Maxima...", "noise=" + maxima + " output=List"); //Find Maxima points above threshold
			
			newImage("Signal", "8-bit white", width, height, 1); 
			setColor(0); //Set color to black
			seed = nResults;
			
			dotmax = nResults;
			if (nResults > 2500) dotmax = 2500;
			if (poly == false) { //Run the faster dots program
				for (q = 0; q < dotmax; q++) {
					dots(getResult("X", q), getResult("Y", q)); //Run dots with different x and y values
					}//End of dots loop
				}
			else { //Run the slower polygon program
				for (q = 0; q < dotmax; q++) {
					crazypoly(getResult("X", q), getResult("Y", q)); //Run dots with different x and y values
					}//End of dots loop
				}
			
			print(nResults + " points processed");
			selectWindow("Signal");
			run("Create Selection");
			roiManager("Add"); //Create Signal selection
			run("Make Inverse"); //Make selection inverted
			roiManager("Add"); //Create Inverse Signal selection
			
			
			selectWindow("MAX_" + path);
			signal(); //Run Signal
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Signal");
			updateResults();
			
			selectWindow("MAX_" + path);
			noise(); //Run Noise
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Cell Noise");
			updateResults();
			
			selectWindow("MAX_" + path);
			background(); //Run Background
			setResult("File", nResults - 1, path);
			setResult("Description", nResults - 1, "Background");
			updateResults();
			
			//Results
			results();
			
			
			//Save Images
			selectWindow("MAX_" + path);
			run("Select None");
			run("Enhance Contrast", "saturated=0.01"); //Make it pretty
			run("Find Maxima...", "noise=" + maxima + " output=[Single Points]"); //Find Maxima single points
			drawString("Local Maxima Points", 10, 40, 'white');
			selectWindow("MAX_" + path);
			run("8-bit");
			drawString(path, 10, 40, 'white');
			selectWindow("Signal");
			drawString("Signal Mask", 10, 40, 'white');
			run("Images to Stack");
			setSlice(3);
			run("Add Slice");
			roiManager("Select", newArray(1,2));
			roiManager("AND");
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
	roiManager("Add");
	roiManager("Select", newArray(1,2));//Select Inverse dots and Li dark
	roiManager("AND"); //Select regions of Li dark and inverse of dots
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
	}//End of signal function

function dots(xi, yi) { //Searches N, S, E, W and then draws an ellipse on mask image
	selectWindow("MAX_" + path);
	bright = getPixel(xi,yi);
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance; r++); //Progress r until there is a drop in brightness (>10% default)
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright > tolerance || getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright < - tolerance * tolerancemultiplier) && r < 15; r++); //Progress r until there is no change in brightness (<10% default)
	x2 = xi + r; //right
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance; r--);
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r - 1, yi)/bright > tolerance || getPixel(xi + r, yi)/bright - getPixel(xi + r - 1, yi)/bright < - tolerance * tolerancemultiplier) && r > -15; r--);
	x1 = xi + r; //left
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright > tolerance || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright < - tolerance * tolerancemultiplier) && r < 15; r++);
	y2 = yi + r; //top
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance; r--);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r - 1)/bright > tolerance || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r - 1)/bright < - tolerance * tolerancemultiplier) && r > -15; r--);
	y1 = yi + r; //bottom
	
	w = x2-x1;
	h = y2-y1;
	
	selectWindow("Signal");
	fillOval(x1, y1, w, h);
	}//End of dot function

function crazypoly(xi, yi) { //Searches in eight cardinal directions and draws polygon on mask image
	selectWindow("MAX_" + path);
	bright = getPixel(xi,yi);
	
	for (r = 0; getPixel(xi, yi + r)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright > tolerance || getPixel(xi, yi + r)/bright - getPixel(xi, yi + r + 1)/bright < - tolerance * tolerancemultiplier) && r < 15; r++); 
	north = yi + r; //North point
	
	for (r = 0; getPixel(xi + r, yi + r)/bright > 1 - tolerance; r++); 
	for (r = r; (getPixel(xi + r, yi + r)/bright - getPixel(xi + r + 1, yi + r + 1)/bright > tolerance || getPixel(xi + r, yi + r)/bright - getPixel(xi + r + 1, yi + r + 1)/bright < - tolerance * tolerancemultiplier) && r < 15; r++); 
	northeast = r; //Northeast point
	
	for (r = 0; getPixel(xi + r, yi)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright > tolerance || getPixel(xi + r, yi)/bright - getPixel(xi + r + 1, yi)/bright < - tolerance * tolerancemultiplier) && r < 15; r++); 
	east = xi + r; //East point
	
	for (r = 0; getPixel(xi + r, yi - r)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi + r, yi - r)/bright - getPixel(xi + r + 1, yi - r - 1)/bright > tolerance || getPixel(xi + r, yi - r)/bright - getPixel(xi + r + 1, yi - r - 1)/bright < - tolerance * tolerancemultiplier) && r < 15; r++);
	southeast = r; //Southeast point
	
	for (r = 0; getPixel(xi, yi - r)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi, yi - r)/bright - getPixel(xi, yi - r - 1)/bright > tolerance || getPixel(xi, yi - r)/bright - getPixel(xi, yi - r - 1)/bright < - tolerance * tolerancemultiplier) && r < 15; r++);
	south = yi - r; //South Point
	
	for (r = 0; getPixel(xi - r, yi - r)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi - r, yi - r)/bright - getPixel(xi - r + 1, yi - r - 1)/bright > tolerance || getPixel(xi - r, yi - r)/bright - getPixel(xi - r + 1, yi - r - 1)/bright < - tolerance * tolerancemultiplier) && r < 15; r++);
	southwest = r; //Southwest point
	
	for (r = 0; getPixel(xi - r, yi)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi - r, yi)/bright - getPixel(xi - r - 1, yi)/bright > tolerance || getPixel(xi - r, yi)/bright - getPixel(xi - r - 1, yi)/bright < - tolerance * tolerancemultiplier) && r < 15; r++);
	west = xi - r; //West point
	
	for (r = 0; getPixel(xi - r, yi + r)/bright > 1 - tolerance; r++);
	for (r = r; (getPixel(xi - r, yi + r)/bright - getPixel(xi - r - 1, yi + r + 1)/bright > tolerance || getPixel(xi - r, yi + r)/bright - getPixel(xi - r - 1, yi + r + 1)/bright < - tolerance * tolerancemultiplier) && r < 15; r++);
	northwest = r; //Northwest point
	
	selectWindow("Signal");
	makePolygon(xi, north, xi + northeast, yi + northeast, east, yi, xi + southeast, yi - southeast, xi, south, xi - southwest, yi - southwest, west, yi, xi - northwest, yi + northwest);
	fill();
	}//End of crazy polygon function

function derivative() { //Creates derivative of image
	showStatus("Creating Derivative Image");
	newImage("Derivative", "16-bit black", width, height, 1);
	for (i = 0; i < height; i++) { //Create derivative image
		showStatus("Creating Derivative Image");
		for (n = 0; n < width; n++) {
			selectWindow("MAX_" + path);
			bright = getPixel(n+1, i+1) - getPixel(n, i);
			selectWindow("Derivative");
			setPixel(n, i, bright);
		}
	}
	selectWindow("Derivative");
	setAutoThreshold("MaxEntropy dark");
	run("Create Selection");
	run("Measure");
	maxima = getResult("Median", nResults - 1) + getResult("StdDev", nResults - 1) * zscore;
	//print(getResult("Mean", nResults - 1), getResult("Median", nResults - 1));
	run("Enhance Contrast", "saturated=0.1");
	run("8-bit");
	drawString("Derivative\nMaxima: " + maxima, 10, 40, 'white');
	
	return maxima;
	}

function results() {
	signoimean = (getResult("Mean", nResults - 3) - getResult("Mean", nResults - 1)) / (getResult("Mean", nResults - 2) - getResult("Mean", nResults - 1));
	signoimedian = (getResult("Median", nResults - 3) - getResult("Median", nResults - 1)) / (getResult("Median", nResults - 2) - getResult("Median", nResults - 1));
	sigrel = getResult("Median", nResults - 3) - getResult("Median", nResults - 1);
	noirel = getResult("Median", nResults - 2) - getResult("Median", nResults - 1);
	if (getResult("Area", nResults - 3) >= getResult("Area", nResults - 2)) { //If signal area is greater than noise area
		signoimean = "inf";
		signoimedian = "inf";
		noirel = 0;
		}
	setResult("Mean StN Ratio", nResults - 3, signoimean);
	setResult("Median StN Ratio", nResults - 3, signoimedian);
	setResult("Median Signal - Background", nResults - 3, sigrel);
	setResult("Median Noise - Background", nResults - 3, noirel);
	setResult("Spots", nResults - 3, seed);
	setResult("Maxima", nResults - 3, maxima);
	if (getResult("Spots", nResults - 3) < 100) setResult("Warnings", nResults - 3, "Low Spot Count");
	if (noirel == 0) setResult("Warnings", nResults - 3, "Signal Area >= Noise Area");
	updateResults();
	String.resetBuffer;
	String.copyResults; //Copy results to clipboard
	String.append(String.paste); //Append results to buffer from clipboard 
	print("[Final]", replace(String.buffer, "	", ", ")); //Print results to new table
	run("Clear Results");
	}

print("-- Done --");
showStatus("Finished.");
}//end of macro