#!/usr/bin/python3
import sys

try:
    assert sys.version_info >= (3, 6)
except AssertionError:
    sys.exit('this script requires  python >= 3.6 version')
import os
import zipfile
from io import BytesIO
import argparse
import requests
from pathlib import Path

binaries = 'index_binaries.yar'


class UrlError(Exception):
    pass


class YaraRules:

    def __init__(self, base_dir):
        self.base_dir = base_dir

    def get_zip(self, url):
        rules = set()
        response = requests.get(url, stream=True)
        if response.status_code == 200:
            zipFile = zipfile.ZipFile(BytesIO(response.raw.read()))
            for item in zipFile.filelist:
                if item.filename.endswith('.yar') or item.filename.endswith(".yara"):
                    zipFile.extract(item)
                    rules.add(item.filename)
        else:
            raise UrlError('code:{response.text}, text:{response.text}')
        return rules


def main(args):
    BASE_DIR = args.get('dir') if args.get('dir') else os.path.join(str(Path.home()), '.cuckoo', 'yara')
    os.chdir(BASE_DIR)

    print(BASE_DIR)

    try:
        assert os.path.exists(BASE_DIR)
    except AssertionError:
        sys.exit('failed to find configured base dir: {BASE_DIR}')

    REPOSITORIES = args.get('list') if args.get('list') else ['https://github.com/Yara-Rules/rules/archive/master.zip']

    for repo in REPOSITORIES:
        try:
            print('gettting url:', repo)
            yara = YaraRules(BASE_DIR)
            yara.get_zip(repo)

        except UrlError:
            print(UrlError)

    index_folder = set()
    for dirpath, dirnames, filenames in os.walk(BASE_DIR, followlinks=True):
        for filename in filenames:
            if filename.endswith((".yar", ".yara")):
                index_folder.add('include "{os.path.join(dirpath, filename)}"')

    print('indexed files:', index_folder.__len__())
    with open(binaries, 'w') as file:
        file.write('\n'.join(list(index_folder)))

    print('file update completed:', binaries)


def arg_parser():
    parser = argparse.ArgumentParser(description='yara rules')
    parser.add_argument(
        '-d',
        '--dir',
        help='default dir is ~.cuckoo/yara/',
        required=False
    )
    parser.add_argument(
        '-l',
        '--list',
        nargs='+',
        help='urls with yara rules',
        required=False
    )
    return vars(parser.parse_args())


if __name__ == '__main__':
    main(arg_parser())

