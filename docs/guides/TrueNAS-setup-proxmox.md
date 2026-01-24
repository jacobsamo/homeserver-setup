# Guide for setting up TrueNAS on Proxmox
Follow this video: https://www.youtube.com/watch?v=pJ1GeH9vODw&t=58s for setting up with proxmox
this one is a good more complex run through https://www.youtube.com/watch?v=67KtKoW4IM0

1. Go to https://www.truenas.com/truenas-community-edition/
2. Right click copy the link for the download truenas button (we will use this in proxmox to download the ISO image)
3. Go to proxmox choose find a storage option on the sidebar 
</br>
<img src="../assets/images/proxmox-storage-sidebar.png">
4. Click on one of the storage items
    - Click on ISO Images
    - Click Download from URL
    - Paste in that download link
    - Click Query URL to get the details of the image
    - After query has finished click Download
5. Once ISO image is download, click "Create VM" in the navbar
6. run through the setup, adjust parameters as needed
7. Find the drive in the DataCenter -> promox -> drives take note of the serial number
8. go to the proxmox -> shell and run `ls -l /dev/disk/by-id/` 
9. find the one that matches your serial and copy the first column 
10. then run `qm set <machine number> -scsi<number of drive> /dev/disk/by-id/<main id>,serial=<serial number>
    - e.g `qm set 104 -scsi1 /dev/disk/by-id/ata-ST4000VN008-2DR166_ZM417ZRR,serial=ZM417ZRR`
    - the reason we add in `,serial=ZM417ZRR` is so that TrueNAS has a serial to reference
11. Go through general TrueNAS setup 
