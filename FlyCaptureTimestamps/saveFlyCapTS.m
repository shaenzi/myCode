%script to save the timestamps
%TSsec is the readout of the timestamps in seconds that I get
relativeTimestampsInSeconds = TSsec - TSsec(1); %take away offset

%new FN
dotIndex = strfind(videoFN,'.tif');
tsFN = strcat(videoFN(1:dotIndex-1),'_TS.mat');
folderForSaving = uigetdir;

%save everything in the workspace
cd(folderForSaving)
save(tsFN)