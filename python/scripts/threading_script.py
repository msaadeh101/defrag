import threading
import zipfile

class AsyncZip(threading.Thread):
    def __init__(self, infile, outfile):
        super().__init__() # Take base class properties
        self.infile = infile
        self.outfile = outfile

    def run(self):
        try:
            with zipfile.ZipFile(self.outfile, 'w', zipfile.ZIP_DEFLATED) as f:
                f.write(self.infile)
            print('Finished background zip of:', self.infile)
        except Exception as e:
            print(f"failed to zip {self.infile}: {e}")

background = AsyncZip('mydata.txt', 'myarchive.zip')
background.start()
print('The main program continues to run in foreground.')

background.join()    # Wait for the background task to finish
print('Main program waited until background was done.')