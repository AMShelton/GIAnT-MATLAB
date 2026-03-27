function [data, meta] = ScanImageTiffWrapper(fn)
A = ScanImageTiffReader(fn);
data = ScanImageTiffDataWrapper(A, fn);
meta = A.metadata();
A.close();
delete(A);

end