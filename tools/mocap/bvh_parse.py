import sys, json, math
import numpy as np

def parse_bvh(path):
    with open(path) as f:
        txt = f.read()
    lines = txt.splitlines()
    i = 0
    joints = []  # list of dicts: name, parent, offset, channels, chan_start
    stack = []
    chan_count = 0
    end_site = False
    while i < len(lines):
        l = lines[i].strip()
        if l.startswith('MOTION'):
            break
        toks = l.split()
        if not toks:
            i += 1; continue
        if toks[0] in ('ROOT', 'JOINT'):
            j = {'name': toks[1], 'parent': stack[-1] if stack else -1,
                 'offset': None, 'channels': [], 'chan_start': None}
            joints.append(j)
            cur = len(joints) - 1
        elif toks[0] == 'End':
            end_site = True
        elif toks[0] == '{':
            if end_site:
                stack.append(-2)
            else:
                stack.append(cur if 'cur' in dir() else -1)
                # actually push index of last joint
                stack[-1] = len(joints) - 1
        elif toks[0] == '}':
            p = stack.pop()
            if p == -2:
                end_site = False
        elif toks[0] == 'OFFSET':
            if not end_site:
                joints[len(joints)-1 if not stack or stack[-1] != len(joints)-1 else stack[-1]]['offset'] = [float(x) for x in toks[1:4]]
        elif toks[0] == 'CHANNELS':
            n = int(toks[1])
            j = joints[-1]
            j['channels'] = toks[2:2+n]
            j['chan_start'] = chan_count
            chan_count += n
        i += 1
    # fix parent linkage: rebuild by re-scanning (simpler robust pass)
    joints2 = []
    stack = []
    i = 0
    end_depth = 0
    while i < len(lines):
        l = lines[i].strip(); toks = l.split()
        if l.startswith('MOTION'): break
        if not toks: i += 1; continue
        if toks[0] in ('ROOT','JOINT'):
            joints2.append({'name': toks[1], 'parent': stack[-1] if stack else -1})
            pending = len(joints2)-1
        elif toks[0] == 'End':
            pending = -2
        elif toks[0] == '{':
            stack.append(pending)
        elif toks[0] == '}':
            stack.pop()
        elif toks[0] == 'OFFSET' and pending != -2 and stack and stack[-1] == pending:
            joints2[pending]['offset'] = [float(x) for x in toks[1:4]]
        i += 1
    for a,b in zip(joints, joints2):
        a['parent'] = b['parent']
        a['offset'] = b.get('offset', a['offset'])
    # motion
    while not lines[i].strip().startswith('MOTION'): i += 1
    i += 1
    nframes = int(lines[i].split(':')[1]); i += 1
    ft = float(lines[i].split(':')[1]); i += 1
    data = np.loadtxt(lines[i:i+nframes])
    if data.ndim == 1: data = data[None,:]
    return joints, data, ft

def rot_mat(axis, deg):
    r = math.radians(deg); c, s = math.cos(r), math.sin(r)
    if axis=='X': return np.array([[1,0,0],[0,c,-s],[0,s,c]])
    if axis=='Y': return np.array([[c,0,s],[0,1,0],[-s,0,c]])
    return np.array([[c,-s,0],[s,c,0],[0,0,1]])

def fk(joints, frame):
    pos = {}
    mats = {}
    for idx, j in enumerate(joints):
        off = np.array(j['offset'])
        R = np.eye(3); T = off.copy()
        cs = j['chan_start']
        for k, ch in enumerate(j['channels']):
            v = frame[cs+k]
            if ch.endswith('position'):
                ax = 'XYZ'.index(ch[0])
                if j['parent'] == -1:
                    T[ax] = v + off[ax]
            else:
                R = R @ rot_mat(ch[0], v)
        if j['parent'] == -1:
            mats[idx] = R; pos[idx] = T
        else:
            pR = mats[j['parent']]; pT = pos[j['parent']]
            pos[idx] = pT + pR @ off
            mats[idx] = pR @ R
    return pos

if __name__ == '__main__':
    cmd = sys.argv[1]
    path = sys.argv[2]
    joints, data, ft = parse_bvh(path)
    if cmd == 'scan':
        hipY = data[:,1]
        base = np.percentile(hipY, 20)
        peak = hipY.max()
        pf = int(hipY.argmax())
        print(json.dumps({'file': path.split('/')[-1], 'frames': len(data), 'fps': round(1/ft,1),
                          'baseY': round(float(base),1), 'peakY': round(float(peak),1),
                          'jump': round(float(peak-base),1), 'peakFrame': pf}))
    elif cmd == 'extract':
        out = sys.argv[3]
        start, end, step = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
        keep = ['Hips','Spine1','Neck','Head','LeftArm','LeftForeArm','LeftHand',
                'RightArm','RightForeArm','RightHand','LeftUpLeg','LeftLeg','LeftFoot',
                'RightUpLeg','RightLeg','RightFoot']
        name2idx = {j['name']: i for i,j in enumerate(joints)}
        keep = [k for k in keep if k in name2idx]
        frames_out = []
        for f in range(start, min(end, len(data)), step):
            p = fk(joints, data[f])
            fr = []
            for k in keep:
                v = p[name2idx[k]]
                fr.append([round(float(v[0]),1), round(float(v[1]),1), round(float(v[2]),1)])
            frames_out.append(fr)
        json.dump({'joints': keep, 'fps': round(1/(ft*step),2), 'frames': frames_out}, open(out,'w'))
        print('wrote', out, len(frames_out), 'frames,', len(keep), 'joints')
