function [M] = nanmedfilt2(A, sz)
%NANMEDFILT2 2-D median filter that ignores NaNs.
%   M = nanmedfilt2(A, sz) median-filters 2-D matrix A with odd tile size sz
%   (scalar or [rows cols]; default 5), ignoring NaNs.
%
%   From Roman Voronov, MathWorks File Exchange #41457
%   (https://www.mathworks.com/matlabcentral/fileexchange/41457-nanmedfilt2),
%   version 1.0.0.0 (2013). See also NOTICE in the repository root.
%   Approach based on discussion:
%   http://www.mathworks.com/matlabcentral/newsreader/view_thread/251787
%
%   Copyright (c) 2013, Roman Voronov
%   All rights reserved.
%
%   Redistribution and use in source and binary forms, with or without
%   modification, are permitted provided that the following conditions are
%   met:
%
%       * Redistributions of source code must retain the above copyright
%         notice, this list of conditions and the following disclaimer.
%       * Redistributions in binary form must reproduce the above copyright
%         notice, this list of conditions and the following disclaimer in
%         the documentation and/or other materials provided with the
%         distribution
%
%   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
%   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

if nargin<2
    sz = 5;
end
if length(sz)==1
    sz = [sz sz];
end
if any(mod(sz,2)==0)
    error('kernel size SZ must be odd)')
end
margin=(sz-1)/2;
AA = nan(size(A)+2*margin);
AA(1+margin(1):end-margin(1),1+margin(2):end-margin(2))=A;
[iB,jB]=ndgrid(1:sz(1),1:sz(2));
is=sub2ind(size(AA),iB,jB);
[iA, jA]=ndgrid(1:size(A,1),1:size(A,2));
iA=sub2ind(size(AA),iA,jA);
idx=bsxfun(@plus,iA(:).',is(:)-1);
B = sort(AA(idx),1);
j=any(isnan(B),1);
last = zeros(1,size(B,2))+size(B,1);
[~, last(j)]=max(isnan(B(:,j)),[],1);
last(j)=last(j)-1;
M = nan(1,size(B,2));
valid = find(last>0);
mid = (1 + last)/2;
i1 = floor(mid(valid));
i2 = ceil(mid(valid));
i1 = sub2ind(size(B),i1,valid);
i2 = sub2ind(size(B),i2,valid);
M(valid) = 0.5*(B(i1) + B(i2));
M = reshape(M,size(A));
end % medianna
