cmake_minimum_required(VERSION 3.0.2)
project(franka_handeye_calibration)

find_package(catkin REQUIRED)
catkin_package()

install(DIRECTORY launch urdf config
        DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION})
