#!/bin/bash

region=${AWS_REGION}
queue=${SQS_QUEUE_URL}
cdn_bucket=${CDN_BUCKET}

# Fetch messages and render them until the queue is drained.
while [ /bin/true ]; do
    # Fetch the next message and extract the S3 URL
    echo "Fetching messages from SQS queue: ${queue}..."
    result=$( \
        aws sqs receive-message \
            --queue-url ${queue} \
            --region ${region} \
            --wait-time-seconds 20 \
            --query Messages[0].[Body,ReceiptHandle] \
        | sed -e 's/^"\(.*\)"$/\1/'\
    )

    if [ -z "${result}" ]; then
        echo "No messages left in queue. Exiting."
        exit 0
    else
        echo "Message: ${result}."

        receipt_handle=$(echo ${result} | sed -e 's/^.*"\([^"]*\)"\s*\]$/\1/')
        echo "Receipt handle: ${receipt_handle}."

        bucket=$(echo ${result} | sed -e 's/^.*arn:aws:s3:::\([^\\]*\)\\".*$/\1/')
        echo "Bucket: ${bucket}."

        key=$(echo ${result} | sed -e 's/^.*\\"key\\":\s*\\"\([^\\]*\)\\".*$/\1/')
        echo "Key: ${key}."

        base=${key%.*}
        ext=${key##*.}

        if [ \
            -n "${result}" -a \
            -n "${receipt_handle}" -a \
            -n "${key}" -a \
            -n "${base}" -a \
            -n "${ext}" -a \
            "${ext}" = "zip" \
        ]; then
            mkdir -p work
            cp clean.js work/

            pushd work

            aws s3 cp s3://${bucket}/${key} . --region ${region}

            echo "Processing ${key}...url: `cat ${key}`"
            FILE_URL=`cat ${key}`
            echo "Creating audiowaveform for ${FILE_URL}"

            curl -o file.mp3 -L $FILE_URL
            base="waveform"

            if audiowaveform -i file.mp3 -o ${base}.dat -z 256; then
                if audiowaveform -i ${base}.dat -o ${base}.png -z 256 --no-axis-labels; then
                    if [ -f ${base}.png ]; then
                        echo "Copying result image ${base}.png to s3://${cdn_bucket}/${key}/${base}.png..."
                        aws s3 cp ${base}.png s3://${cdn_bucket}/${key}/${base}.png
                    else
                        echo "ERROR: audiowaveform source did not generate ${base}.png image."
                    fi
                else
                    echo "ERROR: audiowaveform source did not render png successfully."
                fi

                if audiowaveform -i ${base}.dat -o ${base}.json -z 256; then
                    node clean.js ${base}.json
                    if [ -f ${base}.json ]; then
                        echo "Copying result json ${base}.json to s3://${cdn_bucket}/${key}/${base}.json..."
                        aws s3 cp ${base}.json s3://${cdn_bucket}/${key}/${base}.json
                    else
                        echo "ERROR: audiowaveform source did not generate ${base}.json image."
                    fi
                else
                    echo "ERROR: audiowaveform source did not render png successfully."
                fi
            else
                echo "ERROR: audiowaveform source did not generate dat successfully."
            fi

            echo "Cleaning up..."
            popd
            /bin/rm -rf work

            echo "Deleting message..."
            aws sqs delete-message \
                --queue-url ${queue} \
                --region ${region} \
                --receipt-handle "${receipt_handle}"

        else
            echo "ERROR: Could not extract S3 bucket and key from SQS message."
        fi
    fi
done