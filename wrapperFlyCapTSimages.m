%script to read in timestamp from a FlyCap image rather than a video
%assume all images are in one folder

%go to that folder
[videoFN,videoPath] = uigetfile('*.*');
cd(videoPath)

myPics = ls('*.tif'); %assume that there are ONLY the images in that folder; also change specifier according to file type

%initialise variable to put the 4 ts pixels
nrOfFrames = length(myPics);
TSvaluesPixel = uint8(NaN(nrOfFrames,4));
disp('reading images')
for myN = 1:nrOfFrames
    currentImage = imread(myPics(myN,:));
    TSvaluesPixel(myN,:) = uint8(currentImage(1,1:4));
end

%calculate time stamps in sec
disp('calculating timestamps')
TSsec = readFlyCapTS(TSvaluesPixel);

longFrames = length(find(diff(TSsec)>0.005005))/nrOfFrames;
fprintf('proportion of frames with dt > 0.005005: %.5f\n',longFrames)

%plot time between frames
figure; plot(diff(TSsec),'k.')