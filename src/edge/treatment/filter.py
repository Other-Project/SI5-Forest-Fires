from collections import defaultdict

# Buffer to accumulate payloads per device (sliding window)
_payload_buffer = defaultdict(list)
# Sliding window size
WINDOW_SIZE = 6

def _generate_mean_payload(payloads):
    if not payloads:
        return {}
    mean = {}
    keys = payloads[0].keys()
    for k in keys:
        # Only average numeric fields
        values = [p[k] for p in payloads if isinstance(p.get(k), (int, float))]
        if values:
            mean[k] = sum(values) / len(values)
        else:
            mean[k] = payloads[0][k]
    return mean

def mean_payload(device_id, payload):
    buf = _payload_buffer[device_id]
    buf.append(payload)
    if len(buf) > WINDOW_SIZE:
        buf.pop(0)  # Remove oldest
    return _generate_mean_payload(buf)