import argparse
import nibabel as nb
import numpy as np
import os
import pandas as pd
import sqlite3 as sl


def compute_difference(mask_subject: str, mask_ref: str):
    '''
    Computes number of voxels of the subject mask that are outside the reference mask.
    Parameters
    ----------
    mask_subject : str
        Path to the subject mask.
    mask_ref : str
        Path to the reference mask.

    Returns
    -------
    int
        Number of voxels from the subject mask outside the reference mask.
    '''
    # .nii and .mnc are stored in different order; check if endings are different
    subject_ismnc = bool(mask_subject.endswith('.mnc') or mask_subject.endswith('.mnc.gz'))
    ref_ismnc = bool(mask_ref.endswith('.mnc') or mask_subject.endswith('.mnc.gz'))
    if(subject_ismnc ^ ref_ismnc):
        ref = nb.load(mask_ref).get_fdata() == 0
        ref = np.swapaxes(ref, 0, -1)
    else:
        ref = nb.load(mask_ref).get_fdata() == 0
    subject = nb.load(mask_subject).get_fdata()
    return np.sum(ref*subject)


if __name__ == '__main__':
    parser = argparse.ArgumentParser('Compute number of voxels ')
    parser.add_argument('--mask_subject', required=True, help='path of the subject mask')
    parser.add_argument('--mask_ref', required=True, help='path of the reference mask')
    parser.add_argument('--database', required=True, help='path to database')
    parser.add_argument('--csv', required=False, help='path of the output file')
    args = parser.parse_args()

    diff_vox = compute_difference(mask_subject=args.mask_subject, mask_ref=args.mask_ref)

    base_subject = os.path.basename(args.mask_subject)
    base_split = base_subject.split('_')
    subject_id = ''
    for b in base_split:
        if(b.startswith('sub-')):
            subject_id = b.split('-')[1]
        if(b.startswith('ses-')):
            session_id = b.split('-')[1]
    if(len(subject_id) == 0 or len(session_id) == 0):
        raise(ValueError('Problem with file name; subject or session id not found'))

    db_path = args.database
    # Check if file exists
    if(not os.path.exists(db_path)):
        # Create database
        con = sl.connect(db_path)
        con.execute("""
        CREATE TABLE MASK (
        subject TEXT NOT NULL,
        session TEXT NOT NULL,
        mask_excess FLOAT,
        CONSTRAINT PK_mask PRIMARY KEY (subject,session)
        );
        """)
        con.close()
    data_tuple = (subject_id, session_id, diff_vox)
    con = sl.connect(db_path)
    try:
        con.execute(f'INSERT INTO MASK (subject, session, mask_excess) values{data_tuple}')
    except(sl.IntegrityError):
        con.execute(f'UPDATE MASK SET mask_excess={diff_vox} WHERE subject="{subject_id}" AND session="{session_id}"')
    con.commit()

    if(args.csv is not None):
        # Convert to csv
        data = pd.read_sql("SELECT * FROM MASK", con)
        data.to_csv(args.csv, index=False)
