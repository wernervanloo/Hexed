
// this function compresses the difference between dataOld and dataNew
.function deltaCompress(data, dataOld)
{
  .const minEqualSize = 4

  // -------------------------------------------------------------------------
  // first make a list of all bytes that are equal between dataNew and dataOld
  // -------------------------------------------------------------------------

  .var diff = List()

  .for (var i=0; i<data.size(); i++)
  {
    // read old value, -1 if it does not exist
    .var valueOld = -1
    .if (i<dataOld.size()) { .eval valueOld = dataOld.get(i) }                 

    .eval diff.add((data.get(i) != valueOld))
  }

  // ----------------------------------------------------------------------------------
  // remove equal bytes if they are part of a range that is less than minEqualSize long
  // ----------------------------------------------------------------------------------

  // list of the lengths of the equal run starting from this byte
  .var equalLength = List(); .for (var i=0; i<data.size(); i++) { .eval equalLength.add(0) }

  .for (var i=0; i<data.size(); i++)
  {
    // is this an equal byte?
    .var equal = !diff.get(i)

    // no? continue
    .if (equal)
    {
      .var length = 1

      // calculate the equal length
      .for (var k=i+1; k<data.size(); k++)
      {
        .if (diff.get(k) == false) { .eval length = length + 1 } // if the next byte is also equal. increase the run by 1
        else                       { .eval k = data.size() }     // end the loop
      }

      // delete the equal run if it is less than minEqualSize long
      .if (length < minEqualSize) { .for (var k=i; k<i+length; k++) { .eval diff.set(k, true) } }
      // else, set the length of the run starting from each byte
      else { .for (var k=i; k<i+length; k++) { .eval equalLength.set(k, length-k+i) } }

      .eval i = i + length - 1 // step to the end of the run
    }
  }

  // -----------------
  // compress the data
  // -----------------

  // 00    = end of data
  // 01    = skip bytes
  // 02-7f = run of equal bytes
  // 80-ff = run of literals

  .var compressed    = List()
  .var length        = data.size()
  .var nrLiteral     = 0     // nr of literals to copy
  .var skipBytes     =0      // nr of bytes to skip
  .var startPosition = 0     // start position
  .var pos           = 0
  .const minRun      = 4
  .var loops         = 0     // count # of loops to protect against stuck compressor
  .var forceFlush    = false // force a flush

  // process all data
  .while(pos < length)
  {
    // keep adding literals, until 
    // - there are too many literals, or 
    // - there is a run of repeating bytes, or
    // - we have to skip data

    // read current value
    .var value = data.get(pos)

    // starting from this byte, there is a run of equal bytes that is 1 long
    .var run = 1

    // can we skip data?
    .var skipData = equalLength.get(pos) >= minEqualSize

    // next, check if there is a run of equal bytes, except when skipping data
    // -----------------------------------------------------------------------

    .if (!skipData)
    {
      // check how many equal bytes there are, starting from this position
      .while (!skipData && ((pos+run)<length) && (value==(data.get(pos+run))) && (run<127)) { .eval run = run + 1 }

      // add the current literal if the run is too short
      .if (run<minRun) 
      { 
        .eval nrLiteral = nrLiteral + 1 
        .eval pos = pos + 1
      }
    }

    // flush literals to the output if:
    // --------------------------------
    // - we are skipping data
    // - end of data OR 
    // - 127 literals OR 
    // - a run starts here

    .if ( (nrLiteral>0)  && 
          ( skipData          ||  // skipping data?
           (pos==length)      ||  // or end of file and literals left to flush?
           (nrLiteral == 127) ||  // 127 literals reached?
           (run>=minRun)) )       // equal byte run starts here?
    {
      .eval compressed.add(nrLiteral|$80)
      .for (var i=0; i<nrLiteral; i++) { .eval compressed.add(data.get(startPosition+i)) }

      .eval startPosition = startPosition+nrLiteral
      .eval nrLiteral = 0
    }

    // flush the run of equal bytes to the output
    // ------------------------------------------
    .if (run>=minRun)
    {
      // add equal bytes token and the value
      .eval compressed.add(run, value)

      // update start position
      .eval startPosition = startPosition + run
    }

    // skip bytes in the output
    // ------------------------

    .if (skipData)
    {
      // read how many bytes we can skip to skip
      .eval skipBytes = equalLength.get(pos)

      // first do a check.. if we only skip bytes from here, are we at the end of the file?
      // if this is the case, startPosition is set to end-of-file

      .if ((pos + skipBytes) < length) 
      {
        // limit amount of bytes to skip to 255
        .eval skipBytes = min(skipBytes, 255)

        // write skip byte token and how many bytes to skip
        .eval compressed.add($01, skipBytes)
      }

      // update start position
      .eval startPosition = startPosition + skipBytes
    }

    .eval pos = startPosition+nrLiteral

    // count number of loops to see if there was a fatal error and everything is stuck
    .eval loops = loops + 1
    .if (loops >= 2*length)
    {
      .error "delta compressor stuck"
    }
  } // while pos<length

  // add end of data marker
  .eval compressed.add(0)

  // return output
  .return compressed
}

// this functions RLE compresses bitmapdata in a list
.function compress(data)
{
  .var compressed    = List()
  .var length        = data.size()
  .var nrLiteral     = 0  // nr of literals to copy
  .var startPosition = 0  // start position
  .var pos           = 0
  .const minRun      = 4
  .var loops         = 0  // count # of loops to protect against stuck compressor

  .while(pos < length)
  {
    // keep adding literals, until we have too many or we spot repeating bytes
    .var value = data.get(pos)

    // check how many equal bytes there are from this position
    .var run = 1
    .while (((pos+run)<length) && (value==(data.get(pos+run))) && (run<127)) { .eval run = run + 1 }

    // add a literal if the run is too short
    .if (run<minRun) 
    { 
      .eval nrLiteral = nrLiteral + 1 
      .eval pos = pos + 1
    }

    // flush literals to the output if:
    // - end of data (and literals to flush) OR 
    // - 127 literals OR 
    // - a run of equal bytes start here (and literals to flush)
    .if (((pos==length) && (nrLiteral>0)) ||  // or end of file and literals left to flush?
         (nrLiteral == 127)               ||  // 127 literals reached?
         (run>=minRun)  && (nrLiteral>0))     // equal byte run starts here?
    {
      .eval compressed.add(nrLiteral|$80)
      .for (var i=0; i<nrLiteral; i++) { .eval compressed.add(data.get(startPosition+i)) }

      .eval startPosition = startPosition+nrLiteral
      .eval nrLiteral = 0
    }

    // flush the run to the output
    .if (run>=minRun)
    {
      .eval compressed.add(run)
      .eval compressed.add(value)

      .eval startPosition = startPosition+run
    }

    .eval pos = startPosition+nrLiteral

    // count number of loops to see if there was a fatal error and everything is stuck
    .eval loops = loops + 1
    .if (loops >= 2*length)
    {
      .error "compressor stuck"
    }
  } // while pos<length

  // add end of data marker
  .eval compressed.add(0)

  // return output
  .return compressed
}
