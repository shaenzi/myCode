function TSsec = wrapperFlyCapTS()
%function to select raw video taken with FlyCap2, read it in, make matrix
%of first 4 pixels in each frame (where timestamps are burnt in), then feed
%this into the function calculating the timestamp in seconds, 

%get video file
[videoFN,videoPath] = uigetfile('*.avi');
cd(videoPath)
vidObj = VideoReader(videoFN);
get(vidObj)

%read in video
vidWidth = vidObj.Width;
vidHeight = vidObj.Height;

mov = struct('cdata',zeros(vidHeight,vidWidth,1,'uint8'),...
    'colormap',[]);

disp('reading video data...')
k = 1;
while hasFrame(vidObj)
    mov(k).cdata = readFrame(vidObj);
    k = k+1;
end

%make matrix with first 4 pixels in every frame
nrOfFrames = length(mov);
TSvaluesPixel = uint8(NaN(nrOfFrames,4));
for myN = 1:nrOfFrames
    TSvaluesPixel(myN,:) = uint8(mov(myN).cdata(1,1:4,1));
end

%calculate time stamps in sec
disp('calculating timestamps')
TSsec = readFlyCapTS(TSvaluesPixel);

longFrames = length(find(diff(TSsec)>0.005005))/nrOfFrames;
fprintf('proportion of frames with dt > 0.005005: %.5f\n',longFrames)

%plot time between frames
figure; plot(diff(TSsec),'k.')
