%% ideal ca imaging analysis

%preliminary! need to think about how much I do in ImageJ, and how I save
%and import it...

%% find ca imaging files (tiffs?)and load
% not needed if done in ImageJ
%{
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
%}

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

dotIndex = strfind(ephysFile,'.');
currFile = ephysFile(1:dotIndex-1);
noBGstring = sprintf('file %s no BG subtraction',currFile);

%for now, select cells and export mean from fiji; save as txtfile
[fileNoBGcorrection, pathNoBGcorrection] = uigetfile('*.txt',noBGstring);
cd(pathNoBGcorrection)
dataNoBGcorrection = importdata(fileNoBGcorrection);
cells = dataNoBGcorrection.data(:,2:end);
sizeCells = size(cells);

%with imageJ rolling ball BG subtraction
BGstring = sprintf('file %s BG subtracted',currFile);
[fileBGcorrection, pathBGcorrection] = uigetfile('*.txt',BGstring);
cd(pathBGcorrection)
dataBGcorrection = importdata(fileBGcorrection);
cellsBGsubtracted = dataBGcorrection.data(:,2:end);

%currently no bleaching correction, as I don't image long enough in the end

nCells = sizeCells(1,2);
nFrames = sizeCells(1,1);

%bg subtraction
%last column in cells is bg
%{
%at the moment, my bg subtraction takes away a lot of the signal?!
cellsBGsubtracted = NaN(numFrames,nrCells);
for myN = 1:nrCells
    cellsBGsubtracted(:,myN) = cells(:,myN) - cells(:,6);
end
%}

nInitialDataPoints = 10;

%calculate df/f
%take f to be the mean of the first 6 data points
cellsF = mean(cells(1:nInitialDataPoints,:));
cellsDeltaF = NaN(nFrames,nCells);
for myN = 1:nCells
    cellsDeltaF(:,myN) = (cells(:,myN)-cellsF(1,myN))/cellsF(1,myN);
end

%bg subtracted in imagej with rolling ball algorithm
BGsubtraction = input('diameter of rolling ball BG subtraction: ');
cellsFBGsubtracted = mean(cellsBGsubtracted(1:nInitialDataPoints,:));
cellsDeltaFBGsubtracted = NaN(nFrames,nCells);
for myN = 1:nCells
    cellsDeltaFBGsubtracted(:,myN) = (cellsBGsubtracted(:,myN)-cellsFBGsubtracted(1,myN))/cellsFBGsubtracted(1,myN);
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

fprintf('imaging starts at %d and ends at %d\n',imagingStart, imagingEnd)

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
currentAmpGalvStim = input('current amplitude for galv stim? ');
stimSine(zeroCrossingIndices(1):zeroCrossingIndices(end)-1) = mySine.*currentAmpGalvStim;
%figure; plot(stimsine)

%also add the swim stim into the same trace
currentAmpSwimStim = input('current amplitude for swim stim? ');
maxSync2 = max(sync2.values);
normFactor = currentAmpSwimStim/maxSync2;
sync2Norm = sync2.values.*normFactor;

%% plot to compare BG subtraction vs no BG subtraction

figure;
plot(cellsDeltaF)
hold on
plot(cellsDeltaFBGsubtracted,':')

%% plot ephys, stim and Ca imaging traces together - BG subtracted and no BG subtracted

%timing!
%for v root and stim, simply convert ephys time to actual time
%only for the duration of the imaging
ephysTime = 0:imagingRange-1;
ephysTime = ephysTime*vroot.interval;
%for imaging, distribute the nr of frames within the imaging period

myInterval = imagingRange*imaging.interval/nFrames; %in seconds
imagingTime = myInterval:myInterval:(nFrames)*myInterval; %start after one interval only, as it takes that long to get the first frame!

%figure with BG subtracted cells
figure;
subplot(3,1,1)
%stim
plot(ephysTime,stimSine(imagingStart:imagingEnd-1))
if any(sync2Norm) == 1 %checks for nonzero elements - only plot if there were some
    hold on
    plot(ephysTime,sync2Norm(imagingStart:imagingEnd-1),'k')
end
set(gca,'Box','off')
ylabel('stim (\muA)')
axis([0 max(ephysTime) min(stimSine) max(max(stimSine),max(sync2Norm))])
title('BG subtracted')

subplot(3,1,2)
%ca imaging traces
plot(imagingTime,cellsDeltaFBGsubtracted)
set(gca,'Box','off')
ylabel('\delta F/F')
axis([0 max(imagingTime) min(min(cellsDeltaFBGsubtracted)) max(max(cellsDeltaFBGsubtracted))]) %min and max over all cells

subplot(3,1,3)
%v root
plot(ephysTime,vroot.values(imagingStart:imagingEnd-1))
set(gca,'Box','off')
xlabel('Time (s)')
ylabel('vr (V)')
axis([0 max(ephysTime) -Inf Inf])

%figure with no bg subtraction
figure;
subplot(3,1,1)
%stim
plot(ephysTime,stimSine(imagingStart:imagingEnd-1))
if any(sync2Norm) == 1 %checks for nonzero elements - only plot if there were some
    hold on
    plot(ephysTime,sync2Norm(imagingStart:imagingEnd-1),'k')
end
set(gca,'Box','off')
ylabel('stim (\muA)')
axis([0 max(ephysTime) min(stimSine) max(max(stimSine),max(sync2Norm))])
title('no BG subtraction')

subplot(3,1,2)
%ca imaging traces
plot(imagingTime,cellsDeltaF)
set(gca,'Box','off')
ylabel('\delta F/F')
axis([0 max(imagingTime) min(min(cellsDeltaF)) max(max(cellsDeltaF))]) %min and max over all cells

subplot(3,1,3)
%v root
plot(ephysTime,vroot.values(imagingStart:imagingEnd-1))
set(gca,'Box','off')
xlabel('Time (s)')
ylabel('vr (V)')
axis([0 max(ephysTime) -Inf Inf])

%% find when animal is swimming
%... tricky. manual might be easiest to start
%with... later maybe find beginning of rhythmic bursts??

%% save
cd(pathNoBGcorrection) %this should be the appropriate analysis folder
dotIndex = strfind(ephysFile,'.');
tempFN = strcat(ephysFile(1:dotIndex-1),'_prelimAnalysis.mat');
save(tempFN)