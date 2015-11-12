function TSsec = readFlyCapTS(TSvaluesPixel)
%TSsec = readFlyCapTS(TSvaluesPixel) pass the first 4
%pixel values (which put together give the burnt in timestamp) for each
%frame, i.e. dimensions of TSvaluesPixel: nr of frames by 4


%check the matrix values are uint8
if isa(TSvaluesPixel,'uint8') == 0
    error('input must be uint8')
end

%general stuff, initialise variables
sizePixelArray = size(TSvaluesPixel);
nrOfFrames = sizePixelArray(1);
TSvalues32 = uint32(NaN(nrOfFrames,1));
nrSeconds = NaN(nrOfFrames,1);
cycleCountIntermediate = uint32(NaN(nrOfFrames,1));
cycleCount = NaN(nrOfFrames,1);
cycleOffsetIntermediate = uint32(NaN(nrOfFrames,1));
cycleOffset = NaN(nrOfFrames,1);
TSsec = NaN(nrOfFrames,1);

%loop over all frames
for myN = 1:nrOfFrames
    
    %put the 4 uint8 values together to a uint32
    %if my 4 values are 1 2 3 4, then the order of the bits from the
    %typecast function will be 4 3 2 1.... so need to flip the order of the
    %4 pixels before typecasting such that 1 2 3 4 order is preserved
    TSvalues32(myN) = typecast(fliplr(TSvaluesPixel(myN,:)), 'uint32');
    
    %read nr of seconds: the first 7 bits
    nrSeconds(myN) = double(bitshift(TSvalues32(myN),-25)); %shift to the right by 25 such that only the first 7 bits remain; and convert to double
    
    %read cycle count: next 13 bits (see comment below)
    cycleCountIntermediate(myN) = bitshift(TSvalues32(myN),7); %first, shift 7 bits to the left to get rid of the first 7 bits
    cycleCount(myN) = double(bitshift(cycleCountIntermediate(myN),-19)); %then shift 19 to the right to get rid of last 12 bits and move the appropriate bits to the right end; also convert to double
    
    %read cycle offset: last 12 bits
    cycleOffsetIntermediate(myN) = bitshift(TSvalues32(myN),20); %left-shift by 20 to get rid of the first 20 bits
    cycleOffset(myN) = double(bitshift(cycleOffsetIntermediate(myN),-20)); %right-shift by 20 to get the originally last 12 bits back to the right; also convert to double
    
    %calculate time in seconds
    TSsec(myN) = nrSeconds(myN)+ (cycleCount(myN)+ cycleOffset(myN)/3072)/8000; %8000 because the timer runs at 8kHz; 3072? something to do with the fact that the timer restarts every 128s?
end

%to show the binary stuff: use dec2bin

%comment on calculating the cycle count: could also right-shift by 12 and
%set the (originally) first 7 bits to zero... however, bitset seems to only
%be able to set one bit at a time, so would need another loop (or I am
%using it wrong); so shifting the bits twice seems easier. Same for cycle
%offset
