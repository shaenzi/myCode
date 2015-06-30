%% ideal ca imaging analysis

%preliminary! need to think about how much I do in ImageJ, and how I save
%and import it...

%% find ca imaging files (tiffs?)and load
[imagingFile, imagingPath]=uigetfile('*.tif','select files from Ca imaging');
cd(imagingPath)
caFiles = dir('*.tif');
nFrames = numel(caFiles);
caFileNames = {caFiles.name}';
I = imread(caFileNames{1});
imageSequence = zeros([size(I) nFrames],class(I));
imageSequence(:,:,1) = I;
%
for p = 2:nFrames
    imageSequence(:,:,p) = imread(caFileNames{p}); 
end

%% find ephys files and load (needs to be converted to mat in spike2)
[ephysFile, ephysPath] = uigetfile('*.mat','select ephys file');
cd(ephysPath)
a = load(ephysFile); %this will be a.Ch1, a.Ch2 etc
b = fieldnames(a);
nChns = numel(b); %extract how many channels there are
chns = cell(1,nChns);
for myN = 1:nChns %make a cell with Ch1 ... ChN as fields
    chns{1,myN} = strcat('Ch',num2str(myN));
end

%silly silly silly - both sync channels are called sync1... change in
%setup, and for now rename one of them to sync2

%find the different channels and put to separate struct channel
for myN = 1:nChns
    if strcmpi(a.(chns{1,myN}).title,'imaging') == 1 %case insensitive
        imaging = a.(chns{1,myN});
    elseif strcmpi(a.(chns{1,myN}).title,'vroot') == 1
        vroot = a.(chns{1,myN});
    elseif strcmpi(a.(chns{1,myN}).title,'sync1') == 1
        sync1 = a.(chns{1,myN});
    elseif strcmpi(a.(chns{1,myN}).title,'sync2') == 1
        sync2 = a.(chns{1,myN});
    end
end

%% open ca imaging files and do max intensity projection (maybe do this in
%imagej)

%manually select cells (maybe do this in imagej)

%extract Ca trace for each cell i.e. mean change over all pixels in the
%cell?

%for now, select cells and export mean from fiji
%paste into a variable called cells

%bg subtraction, bleaching correction, calculate delta F/F

%currently no bleaching correction, as I don't image long enough in the end

nCells = input('nr of cells? '); %as the last column is bg

%bg subtraction
%last column in cells is bg
%{
%at the moment, my bg subtraction takes away a lot of the signal?!
cellsBGsubtracted = NaN(numFrames,nrCells);
for myN = 1:nrCells
    cellsBGsubtracted(:,myN) = cells(:,myN) - cells(:,6);
end
%}

nInitialDataPoints = 6;

%calculate df/f
%take f to be the mean of the first 6 data points
cellsF = mean(cells(1:nInitialDataPoints,:));
cellsDeltaF = NaN(nFrames,nCells);
for myN = 1:nCells
    cellsDeltaF(:,myN) = (cells(:,myN)-cellsF(1,myN))/cellsF(1,myN);
end

%bg subtracted in imagej with rolling ball algorithm, diameter 100pi
cellsFBGsubtracted100pi = mean(cellsBGsubtracted100pi(1:nInitialDataPoints,:));
cellsDeltaFBGsubtracted100pi = NaN(nFrames,nCells);
for myN = 1:nCells
    cellsDeltaFBGsubtracted100pi(:,myN) = (cellsBGsubtracted100pi(:,myN)-cellsFBGsubtracted100pi(1,myN))/cellsFBGsubtracted100pi(1,myN);
end

%bg subtracted in imagej with rolling ball algorithm, diameter 50pi
cellsFBGsubtracted50pi = mean(cellsBGsubtracted50pi(1:nInitialDataPoints,:));
cellsDeltaFBGsubtracted50pi = NaN(nFrames,nCells);
for myN = 1:nCells
    cellsDeltaFBGsubtracted50pi(:,myN) = (cellsBGsubtracted50pi(:,myN)-cellsFBGsubtracted50pi(1,myN))/cellsFBGsubtracted50pi(1,myN);
end
%% find beginning and end of imaging

%sampling rate check
if isequal(imaging.interval,vroot.interval)== 0
    disp('imaging and v root trace do not have the same time base!')
    disp('the following calculations will be wrong')
end

%find beginning and end of video
[imagingIndex] = find(imaging.values>0.0005); %as the sampling rate for the imaging is high, there are more than two points here.... 
%since timing is not a strong point of Ca imaging, don't worry about this,
%sub-ms differences will not matter; therefore simply take the first as
%when it starts, and the last as when it ends
imagingStart = imagingIndex(1);
imagingEnd = imagingIndex(end);
imagingRange = (imagingEnd - imagingStart); %in ephys sampling time

%% sync to sine
%the sync of the vestibular stimulation does not give me the actual
%sinewave, but only zero crossings
%so reconstruct the sinewave from these

%'threshold' for zero crossings: 0.001
sinesync1 = [sync1.values' 0];
sinesync2 = [0 sync1.values'];
zeroCrossingUpwardIndices = find(sinesync1 > 0.001 & sinesync2 < 0.001); %but this finds only the upwards ones, missing the last one
zeroCrossingDownwardIndices = find(sinesync1 < 0.001 & sinesync2 > 0.001);
zeroCrossingIndices = [zeroCrossingUpwardIndices zeroCrossingDownwardIndices(end)];
stimDuration = zeroCrossingIndices(end) - zeroCrossingIndices(1);

%check whether the intervals between the zero crossings are equal (or
%within 1 sampling interval) - if yes, just use the first and last, and
%divide by 4 to get the period of the sinewave
if abs(max(diff(zeroCrossingIndices)-median(diff(zeroCrossingIndices)))) > 1
    disp('the 4 cycles differ by more than 0.1ms in length')
end

sineTime = 1:stimDuration;
mySine = sin(2*pi*0.5/10000*sineTime); %this assumes that there are 4 cycles with 0.5Hz
%insert the sine into a vector of zeros at the right time point
%i.e. stim is hardcoded!!
%could also do it that I convert the ephys time to actual time and calculate
%the stim frequency from the zero crossings
stimSine = zeros(1,length(sync1.values));
fprintf('current file: %s\n',ephysFile)
currentAmp = input('what current amplitude was used? ');
stimSine(zeroCrossingIndices(1):zeroCrossingIndices(end)-1) = mySine.*currentAmp;
%figure; plot(stimsine)

%% plot ephys, stim and Ca imaging traces together

%timing!
%for v root and stim, simply convert ephys time to actual time
%only for the duration of the imaging
ephysTime = 0:imagingRange-1;
ephysTime = ephysTime*vroot.interval;
%for imaging, distribute the nr of frames within the imaging period

myInterval = imagingRange*imaging.interval/nFrames; %in seconds
imagingTime = myInterval:myInterval:(nFrames)*myInterval; %start after one interval only, as it takes that long to get the first frame!


figure;
subplot(3,1,1)
%ca imaging traces
plot(imagingTime,cellsDeltaFBGsubtracted100pi)
set(gca,'Box','off')
ylabel('\delta F/F')

subplot(3,1,2)
%stim
plot(ephysTime,stimSine(imagingStart:imagingEnd-1))
set(gca,'Box','off')
ylabel('galv stim')

subplot(3,1,3)
%v root
plot(ephysTime,vroot.values(imagingStart:imagingEnd-1))
set(gca,'Box','off')
xlabel('Time (s)')
ylabel('vr')

%% find when animal is swimming
%... tricky. manual might be easiest to start
%with... later maybe find beginning of rhythmic bursts??