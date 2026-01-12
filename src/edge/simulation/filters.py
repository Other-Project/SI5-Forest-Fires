import numpy as np

def apply_median_filter(data, k):

    n = len(data)
    output = np.zeros(n)
    
    for i in range(n):
        start = max(0, i - k)
        end = min(n, i + k + 1)
        neighborhood = data[start:end]
        
        output[i] = np.median(neighborhood)
        
    return output