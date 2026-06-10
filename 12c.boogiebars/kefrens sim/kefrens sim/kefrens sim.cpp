// kefrens sim.cpp : counts the number of chars needed for drawing the kefrens bars

#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>

using namespace std;

#include <stdio.h>
#include <stdlib.h>

const int maxChars      = 2048; // max number of chars in a charset
const int maxDifference = 4;
int nrChars             = 0;

// charHeight 5 -> 169 chars
// charHeight 6 -> 246 (with different rasterbar)
// charHeight 7 ->

const int barHeight = 13;
const int charHeight = 6;

bool pills = true;

// this is the normal kefrens bar!!
int bar[] = { 0xff,
			  0xff,
			  0x55,
			  0xaa,
			  0x55,  // if we dither this one, we get 248 chars

			  0xaa,
			  0xaa,
			  0xaa,

			  0x55,  // and dither this one
			  0xaa,
			  0x55,
			  0xff,
			  0xff };

/*
// these are high pills!
int bar_pills[] = { 0x00,
				0x14,
				0x7d,
				0x7d,
				0x7d,
				0x7d,
				0x7d,
				0x7d,
				0x7d,
				0x7d,
				0x7d,
				0x14,
				0x00 };
				*/

// these are high pills!
int bar_pills[]  = { 0x55,
				0x55,
				0xff,
				0xff,
				0xff,
				0xff,
				0xff,
				0xff,
				0xff,
				0xff,
				0xff,
				0xaa,
				0xaa };

/*
// these are double pills!
int bar[] = { 0x3c,
			  0xd7,
			  0xd7,
			  0xd7,
			  0xd7,
			  0x3c,
			  0x00,
			  0x3c,
			  0xd7,
			  0xd7,
			  0xd7,
			  0xd7,
			  0x3c };
*/


/*
const int barHeight = 17;
const int charHeight = 6;
int bar[] = { 0xff,
			  0xff,
			  0x55,
			  0xff,
			  0x55,

			  0x55,
			  0xaa,
			  0x55,
			  0xaa,
			  0x55,
			  0xaa,
			  0x55,

			  0x55,
			  0xff,
			  0x55,
			  0xff,
			  0xff };
*/

/*
const int barHeight  = 17;
const int charHeight = 6;
int bar[] = { 0xff,
			  0x55,
	          0xaa,
			  0xff,
			  0x55,
			  0xaa,

	          0xff,
			  0x55,
			  0xaa,
			  0x55,
	          0xff,
			  0xaa,

			  0x55,
			  0xff,
	          0xaa,
			  0x55,
			  0xff};
*/

/*
const int barHeight  = 17;
const int charHeight = 4;
int bar[] = { 0xff,
			  0x55,
			  0xff,
			  0x55,
			  0x55,
			  0xaa,
			  0x55,
			  0xaa,

			  0xaa,
			  0xaa,
			  0x55,
			  0xaa,
			  0x55,
			  0x55,
			  0xff,
			  0x55,
			  0xff }; */


const int plotheight = 32;
int plot[plotheight] = { 0 };           // memory to plot kefrens bars into
int finalCharset[8 * maxChars] = { 0 }; // charset

int usedChars[maxChars][8];

static void clearChars()
{
	for (int chr = 0; chr < maxChars; chr++) {
		for (int i = 0; i < charHeight; i++) {
			usedChars[chr][i] = -1;
		}
	}

	nrChars = 0;  // no chars used up to nnow..
}

static void clearPlot()
{
	for (int i = 0; i < plotheight; i++) plot[i] = 0;
}

static void plotBar(int position)
{
	for (int i = 0; i < barHeight; i++) {
		if (((position + i) >= 0) && ((position + i) < plotheight)) {
			//if (bar[i] != 0)
			//{
				plot[position + i] = bar[i];
			//}
			//else
			//{
			//	if (!(plot[position + i] > 0))
			//	{
			//		plot[position + i] = 0;
			//	}
			//}
		}
	}
}

static void addChars()
{
    // are the chars in the plot area already in usedChars?

	// check all used chars op to now
	for (int chr = 0; chr < nrChars; chr++) {
		bool same = true;

		// is it NOT the same?
		for (int i = 0; i < charHeight; i++) {
			if (usedChars[chr][i] != plot[i]) { same = false; break;  }
		}

		// if we found the char we can exit
		if (same) return;
	}

    // the char is not found, so we have to add it
	for (int i = 0; i < charHeight; i++) {
		usedChars[nrChars][i] = plot[i];
	}
	nrChars++;
	std::cout << "char added " << nrChars << "\n";

	if (nrChars == maxChars+1)
	{
		std::cout << "too many chars, exiting\n";
		exit(0);
	}
}

static int calcStart(int position, int difference)
{
	int start = position - difference;
	if (start < -barHeight) start = -barHeight;
	return -barHeight;
	return start;
}


static int calcEnd(int position, int difference)
{
	int end = position + difference;
	if (end > barHeight) end = charHeight;
	return charHeight;
	return end;
}

int main()
{	
	if (pills) 
	{ 
		for (int i = 0; i < barHeight; i++)
		{
			bar[i] = bar_pills[i];
		}
	}

	// here we calculate the actual # of chars needed to draw the kefrens

	clearChars();   // clear all chars used up to now..

	for (int position1 = -barHeight; position1 <= barHeight; position1++) {
		for (int position2 = calcStart(position1, maxDifference); position2 <= calcEnd(position1, maxDifference); position2++) {
			for (int position3 = calcStart(position2, maxDifference); position3 <= calcEnd(position2, maxDifference); position3++) {
				for (int position4 = calcStart(position3, maxDifference); position4 <= calcEnd(position3, maxDifference); position4++) {
					for (int position5 = calcStart(position4, maxDifference); position5 <= calcEnd(position4, maxDifference); position5++) {
						for (int position6 = calcStart(position5, maxDifference); position6 <= calcEnd(position5, maxDifference); position6++) {
							clearPlot();            // clear the plot area

							plotBar(position6);
							plotBar(position5);
							plotBar(position4);
							plotBar(position3);
							plotBar(position2);
							plotBar(position1);

							addChars();            // test if new chars are used and add it if needed
						}
					}
				}
			}
		}
	}

	// -----------------------
	// write charset .bin file
	// -----------------------

	std::cout << "\nconverting to usable charset\n";

	// do not use chars 0-9 and chars 127-137

	int memPointer = 10 * 8;  // skip chars 0-9
	for (int chr = 0; chr < nrChars; chr++) {

		// copy one char
		for (int byte = 0; byte < charHeight; byte++) {
			finalCharset[memPointer + byte] = usedChars[chr][byte];
		}

		// up 8 bytes in memory
		memPointer += 8;

		if (memPointer == 127 * 8) { memPointer = memPointer + 88; } // skip chars 127-137 (127 = sprite pointers)
	}
	int totalChars = memPointer / 8; // nr of chars in the final charset (with holes)

	
	std::cout << "writing file\n";
	ofstream out;
	if (pills)
	{
		out.open("../../includes/charset1_pills.bin", ios::out | ios::binary);
	}
	else
	{
		out.open("../../includes/charset1.bin", ios::out | ios::binary);
	}

	for (int i = 0; (i < memPointer) && (i < 127*8); i++) {
		out << char(finalCharset[i]);
	}
	out.close();
	std::cout << "charset written\n\n";

	std::cout << "writing file\n";
	if (pills)
	{
		out.open("../../includes/charset2_pills.bin", ios::out | ios::binary);
	}
	else
	{
		out.open("../../includes/charset2.bin", ios::out | ios::binary);
	}

	for (int i = 128*8; (i < memPointer); i++) {
		out << char(finalCharset[i]);
	}
	out.close();
	std::cout << "charset written\n\n";

	// --------------------------------------------------------
	// we also have to make a table (char before -> char after)
	// we have to do this for all the chars that get plotted
	// this means 3 tables
	// --------------------------------------------------------
	// 
	// ldy oldChar,x
	// lda (wasWordt),y  -> table to read from depends on y%8
	// sta store

	int wasWordt[charHeight + barHeight - 1][256] = { 0 };

	// consider all chars (WAS)
	for (int chr = 0; chr < totalChars; chr++) {
		std::cout << "checking char " << chr << "\n";
		// for each char, plot bar in every position
		// if we plot at -barHeight+1 the last pixel of the bar ends up in the top pixel of this char, so this is the first position that we have to consider
		// if the first position is charHeight-1, we only see the last pixel of the bar, so this is last position we have to consider

		for (int plot = -barHeight + 1; plot < charHeight; plot++) {

			// read 'before' char
			int chardata[8]   = { 0 };
			int charBefore[8] = { 0 };
			int charAfter[8]  = { 0 };

			// copy data from the original char (WAS) into all buffers 
			for (int i = 0; i < charHeight; i++) {
				charAfter[i] = charBefore[i] = chardata[i] = finalCharset[chr * 8 + i]; // usedChars[chr][i];
			}

			// plot bar into the char
			// we get how the char will look like after plotting the bar here
			for (int byte = 0; byte < barHeight; byte++) {
				int plotPosition = plot + byte;
				if ((plotPosition >= 0) && (plotPosition < charHeight)) {
					charAfter[plotPosition] = chardata[plotPosition] = bar[byte];
				}
			}

			bool sameChar;

			// now find a char in the charset that is equal to this new char
			for (int chr2 = 0; chr2 < totalChars; chr2++) {
				sameChar = true;

				// is this char equal?
				for (int byte = 0; byte < charHeight; byte++) {
					if (chardata[byte] != finalCharset[chr2*8+byte]) { // usedChars[chr2][byte]) {
						sameChar = false;
						break;
					}
				}

				// if equal, we have found the resulting char
				if (sameChar) {
					if (chr2 == 0) { chr2 = 10; } // skip chars 0-9

					wasWordt[plot + barHeight - 1][chr] = chr2;
					break;
				}
			}

			// check if the char is found, if not we are in trouble! There must be a char that is missing from the charset :-(
			if (!sameChar) {
				std::cout << "error! char not found\n";
				std::cout << "charNr : " << chr << "\n";
				std::cout << "plotpos : " << plot << "\n\n";


				std::cout << "char before : ";
				for (int j = 0; j < 8; j++)
				{
					std::cout << charBefore[j] << ",";
				}

				std::cout << "\nchar after : ";
				for (int j = 0; j < 8; j++)
				{
					std::cout << charAfter[j] << ",";
				}
				std::cout << "\n";
				exit(0);
			}
		}
	}

	std::cout << "waswordt ready\n";

	for (int file = 0; file < (charHeight + barHeight - 1); file++)
	{
		string string1 = "../../includes/waswordt";

		if (pills)
		{
			string1 = "../../includes/waswordt_pills";
		}

		string string2 = std::to_string(file);
		string string3 = ".bin";
		string filename = string1 + string2 + string3;
		ofstream out;
			out.open(filename, ios::out | ios::binary);

			for (int i = 0; i < totalChars; i++) {
				out << char(wasWordt[file][i]);
			}
		out.close();
	}

	std::cout << "waswordt written\n";
}