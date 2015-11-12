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
tic
for myN = 1:nrOfFrames
    currentImage = imread(myPics(myN,:));
    TSvaluesPixel(myN,:) = uint8(currentImage(1,1:4));
    if mod(myN, 100) == 0
        fprintf('at frame %i\n', myN)
    end
end
fprintf('reading the images took %.2f seconds\n',toc)

%calculate time stamps in sec
disp('calculating timestamps')
TSsec = readFlyCapTS(TSvaluesPixel);
relativeTimestampsInSeconds = TSsec - TSsec(1); %take away offset

nLongFrames = length(find(diff(TSsec)>0.00505));
proportionLongFrames = nLongFrames/nrOfFrames;
fprintf('number of long frames with dt > 5.05ms: %d\n',nLongFrames)
fprintf('proportion of frames with dt > 5.05ms: %.5f\n',proportionLongFrames)

%plot time between frames
figure; plot(diff(TSsec),'k.')

%% save?

%ask whether I want to save
promptMessage = sprintf('Do you want to save?');
button = questdlg(promptMessage, 'Save', 'Save', 'Cancel', 'Save');
if strcmpi(button, 'Cancel')
	return; % Or break or continue
end

%new FN
dotIndex = strfind(videoFN,'.tif');
tsFN = strcat(videoFN(1:dotIndex-1),'_TS.mat');
folderForSaving = uigetdir;

%save everything in the workspace
cd(folderForSaving)
save(tsFN)