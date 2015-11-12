%script to see whether I can track the tadpole in Matlab.....

%localise folders: images to be analysed, where the tracked images should be saved (separate folder
%s.t. I can easily load them into Fiji), and also another one for saving
%the mat file with the analysis
imageFolder = uigetdir('','folder with original images');
imageAnalysisFolder = uigetdir('','folder to put the tracked images');
matAnalysisFolder = uigetdir('','folder to save the mat file');

%go to image folder and get all the images
cd(imageFolder)
tic
listing = dir(pwd);

%get rid of the '.' and '..' in the listing
listing=listing(~ismember({listing.name},{'.','..'}));
fprintf('it took %.2f s to load all the image names\n', toc)


%set threshold value manually... this might differ between
%sessions!!!_________________--_--------------------------------------
thresholdValue = 90;

%initialise variables
numFrames = length(listing);
centroidsAllFrames = NaN(numFrames, 2);
areaAllFrames = NaN(numFrames, 1);
TSallFrames = NaN(numFrames,1);

%load first image and wait for user to click the four edges of the tank
firstImage = imread(listing(1).name);
h0 = figure; imshow(firstImage)
tank = struct;
[tank.tankX, tank.tankY] = ginput(4);
tank.XLim = [min(tank.tankX), max(tank.tankX)];
tank.YLim = [min(tank.tankY), max(tank.tankY)];
tank.tankRect = [tank.XLim(1), tank.YLim(1), tank.XLim(2) - tank.XLim(1), tank.YLim(2) - tank.YLim(1)];
close(h0)


tic
%loop through all frames, calculate TS and track the animal
for myN = 1:numFrames
    
    %return to image folder (leave it at the end of the loop to save the
    %tracked image file)
    cd(imageFolder)
    
    %determine current image and load it
    baseFileName = listing(myN).name;
    [pathstr,name,ext] = fileparts(which(baseFileName));
    fullFileName = fullfile(pathstr, baseFileName);
    originalImage = imread(fullFileName);
    croppedImage = imcrop(originalImage, tank.tankRect);
    %[rows, columns, numberOfColorChannels] = size(originalImage);
    
    %convert to binary and threshold
    binaryImage = croppedImage < thresholdValue;
    
    %remove the very small blobs
    npix = 10;
    binaryImage = bwareaopen(binaryImage, npix);
    
    %find all the blobs that are still here
    blobMeasurements = regionprops(binaryImage, croppedImage, 'all');
    numberOfBlobs = size(blobMeasurements, 1);
    allBlobCentroids = [blobMeasurements.Centroid];
    centroidsX = allBlobCentroids(1:2:end-1);
    centroidsY = allBlobCentroids(2:2:end);
    
    %find the largest blob, assuming this is the animal
    if numberOfBlobs > 1
        [myMax, index] = max([blobMeasurements.Area]);
    else 
        index = 1;
    end
    centroidsAllFrames(myN, 1) = centroidsX(index);
    centroidsAllFrames(myN, 2) = centroidsY(index);
    areaAllFrames(myN, 1) = blobMeasurements(index).Area;
    
    %go to analysis folder, make an image with the centroid plotted as a
    %cross, and save it there
    %that way I can go check the tracking afterwards; if ok, can still
    %delete all those images again
    cd(imageAnalysisFolder)
    newFN = strcat(name, 'trackingDot.png');
    h1 = figure; imshow(croppedImage)
    hold on; plot(centroidsX(index), centroidsY(index), 'w+')
    %saveas(h, newFN)
    F = getframe(h1);
    trackedImage = frame2im(F);
    imwrite(trackedImage, newFN)
    close(h1)
    
    %calculate TS
    TSvaluesPixel = uint8(originalImage(1,1:4));
    TSallFrames(myN, 1) = readFlyCapTS(TSvaluesPixel);
    
    %to get an idea of the progress
    if mod(myN, 200) == 0
        disp(myN)
    end
end
fprintf('it took %.2f s to go through all the images\n', toc);

figure; plot(centroidsAllFrames(:,1), centroidsAllFrames(:,2))
axis image

%save the 
cd(matAnalysisFolder)
endIndex = strfind(name, '2015');
matFN = strcat(name(1:endIndex(2)-1),'matlabTrackingTS.mat'); 
    
save(matFN, 'TSallFrames', 'centroidsAllFrames', 'areaAllFrames', 'imageFolder', ...
    'imageAnalysisFolder', 'matAnalysisFolder', 'tank')

% working with cropped image -> the coordinates of the animal will also be
% in cropped image coordinates... to get back to the original need to add
% (?) tank.XLim(1) to x and tank.YLim(1) to y
