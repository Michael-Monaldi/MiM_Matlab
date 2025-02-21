function nii_sliceTime(fMRIname)
%Adjust for slice time order 
% fMRIname    : NIFTI format 4D fMRI image
%               assumes BIDS format file (img.nii, img.json)
%Examples
% nii_sliceTime('img4d.nii');  %slice timing with automatic slice order and TR detection
% nii_sliceTime; %use GUI
if isempty(which('spm')) || ~strcmp(spm('Ver'),'SPM12')
    error('SPM12 (or later) required');
end;
if ~exist('fMRIname', 'var') || ~exist(fMRIname, 'file')
    fMRIname = spm_select(1,'image','Select 4D data for slice timing');
end
[pth,nam, ext] = spm_fileparts( deblank(fMRIname(1,:)));
BIDSname = fullfile(pth, [nam, '.json']);
if ~exist(BIDSname,'file')
    warning('Unable to find BIDS file %s (use "dcm2niix -b y")', BIDSname); %#ok<WNTAG>
    return;
end
[stMsec, TRsec] = bidsSliceTiming(BIDSname);
if isempty(stMsec) || isempty(TRsec), error('Update dcm2niix? Unable determine slice timeing or TR from BIDS file %s', BIDSname); end;

unique_slicetimes = unique(stMsec);
if length(unique_slicetimes) == length(stMsec)/3
    % multiband by 3s (UF Siemens 3T)
    refslice = median(stMsec);
    if ~any(stMsec == refslice)
        difference_from_median = (stMsec - refslice);
        refslice = min(stMsec(difference_from_median > 0));
    end  
elseif length(unique_slicetimes) == length(stMsec)
    % ascending or descending
    refslice = max(stMsec)/2;
    fprintf('Setting reference slice as %g ms (slice ordering assumed to be from foot to head)\n', refslice);
else
    error('Something is not right with slice order, check whether multiband not equal to 3')
end

timing = [0 TRsec];
prefix = 'slicetimedAdjustFunc_';

spm_slice_timing(fullfile(pth, [nam, ext]), stMsec, refslice, timing, prefix)
end 

function [sliceTimeMsec, TRsec] = bidsSliceTiming(fnm)
%return slice acquisition times and repetition time
sliceTime = jsonVal(fnm, '"SliceTiming":');
TRsec = jsonVal(fnm, '"RepetitionTime":');
sliceTimeMsec = sliceTime * 1000; %convert sec to msec
%end bidsSliceTiming();
end

function val = jsonVal(fnm, key)
%read numeric values saved in JSON format
% e.g. use 
%    bidsVal1(fnm, '"RepetitionTime":') 
%for file with 
%   "RepetitionTime": 3,
val = [];
if ~exist(fnm, 'file'), return; end;
txt = fileread(fnm);
pos = strfind(txt,key);
if isempty(pos), return; end;
txt = txt(pos(1)+numel(key): end);
pos = strfind(txt,'[');
posComma = strfind(txt,',');
if isempty(posComma), return; end; %nothing to do
if isempty(pos) || (posComma(1) < pos(1)) %single value, not array
    txt = txt(1: posComma(1)-1);
    val = str2double(txt); %BIDS=sec, SPM=msec
    return; 
end;
txt = txt(pos(1)+1: end);
pos = strfind(txt,']');
if isempty(pos), return; end;
txt = txt(1: pos(1)-1);
val = str2num(txt); %#ok<ST2NM> %BIDS=sec, SPM=msec
%end jsonVal()
end