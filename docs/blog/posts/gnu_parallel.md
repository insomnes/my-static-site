---
date:
  created: 2024-10-24
---

# Embarrassingly GNU parallel
The [GNU parallel](https://www.gnu.org/software/parallel/) is a great tool for
solving embarrassingly parallel problems. Despite the problem class name parallelization
is not embarrassing at all and can be hard to implement. In this post I would like to
show some of the simple ETL and ML task parallelization examples using GNU parallel.

<!-- more -->

## Examples requirements 
For running examples in this post you will need to install:

- [GNU parallel](https://www.gnu.org/software/parallel/)
- [jq](https://jqlang.github.io/jq/download/)
- [python](https://www.python.org/downloads/)
- [curl](https://curl.se/download.html)
- [imagemagick](https://imagemagick.org/script/download.php)


## Basics
In it's essence `parallel` takes a list of arguments and runs a command for each of them
in parallel, here is a simple example with the `echo` command:
```
parallel echo ::: 1 2 3 4 5 6 7 8 9 10
```
The output shows that commands were run in parallel and output is mixed:
```
3
1
2
4
5
6
8
7
10
9
```

That's it! It also has a lot of options and features, but the basic usage is very simple.
In the case like above you can just use `xargs` but `parallel` has some nice features
like combining arguments, progress bar, retries, and more.

In next segments I will show some examples of using `parallel` for more practical tasks.
And some of the options that can be useful for them.

## ETL pipeline
Let's say we want to load bunch of currency exchange rates from the web from 2024-04-01
until 2024-09-30 and store them in a single CSV for each of the currencies.
Each date will require a separate HTTP request to the very starnge [exchange-api](https://github.com/fawazahmed0/exchange-api) and may take some time to complete.
So we can parallelize this task based on currencies and dates.


### Single date downloading
First let's see how we can download EUR exchange rates for a single date and EUR:
```bash
"https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2024-04-01/v1/currencies/eur.min.json"
```
If everything is working correctly you should see the exchange rates for EUR for the 2024-01-01.
We also want to extract only date and EUR, GBP, USD, JPY (to simplify the script we include each currency)
exchange rates from the JSON response. We can do this with `jq`:
```bash
curl -s "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2024-04-01/v1/currencies/eur.min.json" | \
    jq -r '[.date, $cur, .[$cur].eur, .[$cur].gbp, .[$cur].usd, .[$cur].jpy] | @csv' --arg cur "eur"
```
`jq` will simply extrach key values from the JSON response by provided path,
and we will format them as CSV string:
```
"2024-04-01","eur",1,0.854189,1.079325,163.325077
```

That's quite a big command, so let's put it inside a simple bash script `get_cur.sh`,
with currency and date as arguments:
```bash
#!/bin/bash

curl -s "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$2/v1/currencies/$1.min.json" | \
    jq -r '[.date, $cur, .[$cur].eur, .[$cur].gbp, .[$cur].usd, .[$cur].jpy] | @csv' --arg cur "$1"
```

Don't forget to make the script executable and test it:
```bash
chmod 755 get_cur.sh
./get_cur.sh eur 2024-04-01
```

This will allow us to simplify the `parallel` command later.


### Generate list of dates
Lets generate list of dates we want to download with this bizarre python one-liner:
```bash
python -c 'import datetime; [print(v) for v in [(datetime.date(2024, 4, 1) + datetime.timedelta(days=i)).strftime("%Y-%m-%d") for i in range((datetime.date(2024, 9, 30) - datetime.date(2024, 4, 1)).days + 1)]]' > dates.txt
```

Check the content of the `dates.txt` file:
```bash
head dates.txt && echo "..." && tail dates.txt
```

### Check future parallel pipeline
First we want to see how parallelization works on a simple level again
(let's also limit the number of parallel tasks to 4 with `-j` (`--jobs`) option).
We use `--dry-run` option to see the commands that will be run.
The `:::` is used to provide input from a list of arguments.

This command will just show us the first 10 dates from the `dates.txt` file:

```bash
parallel -j 4 --dry-run ::: $(head -n 10 dates.txt)
```

Let's check the output:
```
2024-04-01
2024-04-02
2024-04-04
2024-04-03
2024-04-05
2024-04-07
2024-04-06
2024-04-08
2024-04-09
2024-04-10
```
It works! But the output is mixed, because tasks are run in parallel. Let's use the `-k`(`--keep-order`) option to fix this:
```bash
parallel -k -j 4 --dry-run ::: $(head -n 10 dates.txt)
```
Now the output should be in order of the lines in file:
```
2024-04-01
2024-04-02
2024-04-03
2024-04-04
2024-04-05
2024-04-06
2024-04-07
2024-04-08
2024-04-09
2024-04-10
```

Awesome! Let's increase job count to 8 and combine currency and date arguments,
this will do it for the first 4 lines of the `dates.txt` file:
```bash
 parallel -k -j 8 --dry-run ::: eur gbp usd jpy ::: $(head -n 4 dates.txt)
```

The output should be:
```
eur 2024-04-01
eur 2024-04-02
eur 2024-04-03
eur 2024-04-04
gbp 2024-04-01
gbp 2024-04-02
gbp 2024-04-03
gbp 2024-04-04
usd 2024-04-01
usd 2024-04-02
usd 2024-04-03
usd 2024-04-04
jpy 2024-04-01
jpy 2024-04-02
jpy 2024-04-03
jpy 2024-04-04
```

It works! Now let's try try to run it with our `get_cur.sh` script, the `{}` is a placeholder for
the input argument (combination of currency and date like `eur 2024-04-01`):
```bash
parallel -k -j 8 './get_cur.sh {}' ::: eur gbp usd jpy ::: $(head -n 4 dates.txt)
```

If you can see the output of the exchange rates for the first 4 days of April 2024,
if then you've done everything correctly!

### Full pipeline
Now we can run the full pipeline with all dates (`--bar` option will show progress bar),
the `::::` is used to provide input from a file, and here we use the `dates.txt` file.
The `{1}` is a placeholder for the first argument from the input:
```bash
echo date,currency,eur,gbp,usd,jpy > exc_rates.csv && \
    parallel --bar -k -j 8 './get_cur.sh {}' ::: eur gbp usd jpy :::: dates.txt >> exc_rates.csv
```

Check the output:
```bash
head exc_rates.csv && echo "..." && tail exc_rates.csv
```

Ta-da! We have all CSVs with exchange rates and have loaded them in parallel.

### Serial variant comparison
I encourage you to compare our parallel pipeline with the naive serial one
by creation of `get_cur_serial.sh`:
```bash
#!/bin/bash

echo "date,currency,eur,gbp,usd,jpy" > exc_rates_serial.csv
for cur in eur gbp usd jpy; do
    echo "Getting exchange rates for $cur"
    while read -r date; do
        ./get_cur.sh "$cur" "$date" >> exc_rates_serial.csv
    done < dates.txt
done
```
Don't forget to make the script executable and test it:
```bash
chmod 755 get_cur_serial.sh
./get_cur_serial.sh
```

## ML batch inference pipeline
Let's say for the sake of example we have a simple
ML pipeline for inference that consists of 3 steps:

1. Resize images to 256x256 pixels.
2. Run inference with a pre-trained `MobileNetV2` model.

This pipeline is a very toy example, but it is simple and is a good example for
parallelization capabilities and external image preprocessing.

### Images downloading
We will use [Stanford Dogs dataset](http://vision.stanford.edu/aditya86/ImageNetDogs/):
```bash
curl -O http://vision.stanford.edu/aditya86/ImageNetDogs/images.tar
```


Unpacking `images.tar` will create `Images` directory with images in it:
```bash
tar -xf images.tar
```

### Images resizing
This dataset contains images of different sizes, so we need to resize them to 256x256
as `MobileNetV2` model requires this size. We also want to strip metadata from images
and put them in a separate directory `prepro_images`.
We can do this with `imagemagick` and our friend `parallel`:
```bash
rm -rf ./prepro_images && mkdir ./prepro_images && \
    find ./Images -type f -name "*.jpg" | 
    parallel --bar --jobs 6 magick {} -resize 224x224^ \
    -gravity center -extent 224x224 -strip \
    ./prepro_images/{/}
```

This may take some time to finish, but after that you should have all images resized.

### Inference script
Install `tensorflow`, `keras`, and `Pillow`:
```bash
pip install tensorflow keras Pillow
```

Now we need to write a script that will run inference on the images. Calling separate
script for each image is not efficient, so we will use `parallel` again and will write
script in a way that it will accept multiple image paths as arguments:
```python
"""
This script is used to run inference on multiple images using MobileNetV2 model.
It takes a list of image paths as input and prints the top-1 class predictions for each image.
Output format: <image_name>,<class_name>,<class_probability>
"""

import os
# We should set the environment variable before importing TensorFlow
# This will allow us to suppress TF log messages
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
# Limit the number of threads used by TensorFlow, cause we are running script via parallel
os.environ['OMP_NUM_THREADS'] = '2'
os.environ['TF_NUM_INTEROP_THREADS'] = '2'

from keras.api.preprocessing import image
from keras.api.applications.mobilenet_v2 import MobileNetV2, preprocess_input, decode_predictions
import numpy as np
import sys


model = MobileNetV2(weights='imagenet')

def run_inference(image_path: str):
    # We can omit target_size parameter, cause we have already resized images
    # to 224x224 pixels in the previous step
    img = image.load_img(image_path)
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)
    
    preds = model.predict(img_array, verbose=0)
    fname = os.path.basename(image_path)
    decoded = decode_predictions(preds, top=1)[0][0]
    class_name, probability = decoded[1], decoded[2]

    # This will allow us to write output to stdout and we can redirect it to a file later
    # We are sure that file names and class names don't contain commas or quotes
    sys.stdout.write(f'"{fname}","{class_name}",{probability}\n')

if __name__ == '__main__':
    # This way we can pass multiple image paths as arguments to the script
    images = sys.argv[1:]
    for image_path in images:
        run_inference(image_path)
```

Let's check if the script works on some files:
```bash
python run_inference.py prepro_images/n02085620_7.jpg prepro_images/n02116738_10872.jpg
```

After a bit of time you should see the output with image names, class names, and probabilities:
```
"n02085620_7.jpg","Chihuahua",0.9873059988021851
"n02116738_10872.jpg","African_hunting_dog",0.893324077129364
```

Yay! Now we can start parallelizing the inference pipeline.

### Prepare the pipeline
Let's generate the list of image paths:
```bash
find ./prepro_images/ -type f -name "*.jpg" > image_paths.txt
```

And check with `--dry-run` option how the pipeline will work 
(`-N 2` option tells `parallel` to provide arguments to the script by chunks of 2):
```bash
parallel --jobs 2 --dry-run -N 2 python run_inference.py ::: $(head -n 10 image_paths.txt)
```

The output should be something like:
```
python run_inference.py ./prepro_images/n02097047_2917.jpg ./prepro_images/n02097047_6188.jpg
python run_inference.py ./prepro_images/n02097047_1093.jpg ./prepro_images/n02097047_2190.jpg
python run_inference.py ./prepro_images/n02097047_3103.jpg ./prepro_images/n02097047_2126.jpg
python run_inference.py ./prepro_images/n02097047_5205.jpg ./prepro_images/n02097047_2865.jpg
python run_inference.py ./prepro_images/n02097047_2233.jpg ./prepro_images/n02097047_5223.jpg
```
Ok! This looks good.

### Run the pipeline
Now we can run the full pipeline with all images and save the results to a CSV files 
(`--bar` for progress bar and chunk size of 500 images):
```bash
echo "image_name,class_name,probability" > inference_results.csv && \
    parallel --bar --jobs 4 -N 500 \
    python run_inference.py :::: image_paths.txt \
    >> inference_results.csv
 
```
This will take a while for sure, but after that we can check the results:
```bash
head inference_results.csv && echo "..." && tail inference_results.csv
```

And that's it! We have run the ML pipeline in parallel and saved the results to a CSV file.

## Conclusion
In this post I've wanted to show you that CLI parallelization can go beyond simple `xargs`
cases and with usage of `parallel` we can achieve quite complex parallel pipelines without
writing `multiprocessing` or `threading` code. 

Options like `--retries`, `--halt`, `--timeout` and `--delay` can be useful for more advanced
tasks. And `parallel` even allows you to resume failed tasks with `--resume-failed` option.

Yes, it is quite old school and quirky; and you should not use it for very complex pipelines
or performance-critical tasks. However, for many everyday tasks that benefit from parallel execution,
it offers a practical and efficient solution without the overhead of writing additional code.
